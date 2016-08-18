    chai = require 'chai'
    chai.use require 'chai-as-promised'
    chai.should()

    request = (require 'superagent-as-promised') require 'superagent'

    describe "munin", ->
      @timeout 4000
      it 'should return proper autoconf', (done) ->
        munin = require '../src/munin'
        {server} = munin {}
        server.on 'listening', ->
          request
          .get 'http://127.0.0.1:3949/autoconf'
          .then ({text}) ->
            text.should.equal 'yes\n'
            done()

      it 'should return config', (done) ->
        munin = require '../src/munin'
        {server} = munin munin: port:3940
        server.on 'listening', ->
          request
          .get 'http://127.0.0.1:3940/config'
          .then ({text}) ->
            text.should.match /opensips_registrar_accepted/
            done()

    describe 'munin live', ->

      Promise = require 'bluebird'
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
        our_server = service
          web:
            port: 34349
            host: '172.17.0.1'
          usrloc: 'location'
          usrloc_options: db: require 'memdown'
        .then ({server}) ->
          opensips b_port, compile config
          Promise.delay 3000

      after ->
        kill b_port

      it 'should return value', (done) ->
        munin = require '../src/munin'
        {server} = munin
          munin: port:3941
          httpd_port: b_port
        success = false
        server.on 'listening', ->
          request
          .get 'http://127.0.0.1:3941/'
          .then ({text}) ->
            text.should.match /opensips_registrar_accepted.value 0/
            done() unless success
            success = true
