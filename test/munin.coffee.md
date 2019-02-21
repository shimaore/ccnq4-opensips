    chai = require 'chai'
    chai.use require 'chai-as-promised'
    chai.should()
    sleep = (timeout) -> new Promise (resolve) -> setTimeout resolve, timeout
    random = (n) ->
      n + Math.ceil 100 * Math.random()

    hostname = '127.0.0.1'

    request = require 'superagent'

    describe "munin", ->
      @timeout 4000
      it 'should return proper autoconf', ->
        munin = require '../src/munin'
        server = await munin {}
        after ->
          server.close()
        {text} = await request.get 'http://127.0.0.1:3949/autoconf'
        text.should.equal 'yes\n'

      it 'should return config', ->
        m_port = random 3940
        munin = require '../src/munin'
        server = await munin munin: port: m_port
        after ->
          server.close()
        {text} = await request.get "http://127.0.0.1:#{m_port}/config"
        text.should.match /opensips_registrar_accepted/

    describe 'munin live', ->

      opensips = require './opensips'
      port = random 7950
      a_port = port++
      b_port = port++

      our_server = null
      kill = null

      before ->
        @timeout 8000

        build_config = require '../config'
        {compile} = require '../src/config/compiler'

        config = build_config require './config1.json'
        config.httpd_ip = null
        config.httpd_port = b_port

        service = require '../src/client/main'
        db_port = random 34349
        config.db_url = "http://#{hostname}:#{db_port}"
        server = await service
          web:
            port: db_port
            host: hostname
          prefix_admin: 'foo'
          usrloc: 'location'
        our_server = server
        kill = await opensips b_port, compile config
        await sleep 3000

      after ->
        await sleep 1000
        kill b_port
        our_server.close()

      it 'should return value', ->
        munin = require '../src/munin'
        m_port = random 3941
        server = await munin
          munin:
            host: hostname
            port: m_port
          httpd_port: b_port
        after ->
          server.close()
        {text} = await request.get "http://#{hostname}:#{m_port}/"
        text.should.match /opensips_registrar_accepted.value 0/
