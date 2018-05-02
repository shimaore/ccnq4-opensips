    chai = require 'chai'
    chai.use require 'chai-as-promised'
    chai.should()
    sleep = (timeout) -> new Promise (resolve) -> setTimeout resolve, timeout

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
        munin = require '../src/munin'
        server = await munin munin: port:3940
        after ->
          server.close()
        {text} = await request.get 'http://127.0.0.1:3940/config'
        text.should.match /opensips_registrar_accepted/

    describe 'munin live', ->

      {opensips,kill} = require './opensips'
      port = 7950
      a_port = port++
      b_port = port++

      our_server = null

      before ->
        @timeout 8000

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config1.json'
        config.httpd_ip = null
        config.httpd_port = b_port

        service = require '../src/client/main'
        config.db_url = 'http://172.17.0.1:34349'
        server = await service
          web:
            port: 34349
            host: '172.17.0.1'
          usrloc: 'location'
          usrloc_options: db: require 'memdown'
        our_server = server
        opensips b_port, compile config # async
        await sleep 3000

      after ->
        await sleep 1000
        await kill b_port
        our_server.close()

      it 'should return value', ->
        munin = require '../src/munin'
        server = await munin
          munin: port:3941
          httpd_port: b_port
        after ->
          server.close()
        {text} = await request.get 'http://127.0.0.1:3941/'
        text.should.match /opensips_registrar_accepted.value 0/
