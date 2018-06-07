    chai = require 'chai'
    chai.should()
    hostname = '127.0.0.1'

    debug = (require 'tangible') 'test:client'

    sleep = (timeout) -> new Promise (resolve) -> setTimeout resolve, timeout
    random = (n) ->
      n + Math.ceil 100 * Math.random()

    describe 'The `client` configuration', ->
      request = require 'superagent'
      Promise = require 'bluebird'
      opensips = require './opensips'

      port = random 7600
      a_port = port++
      b_port = port++

      our_server = null
      kill = null

      before ->
        @timeout 15000
        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config1.json'
        config.httpd_ip = null
        config.httpd_port = b_port

        service = require '../src/client/main'
        config.db_url = "http://#{hostname}:34344"
        our_server = await service
          web:
            port: 34344
            host: hostname
          usrloc: 'location'
          usrloc_options: db: require 'memdown'
        debug "Server ready"
        kill = await opensips b_port, compile config
        await sleep 10000
        debug "Start"

      after ->
        @timeout 5000
        await sleep 1000
        await kill b_port
        await sleep 2000
        our_server.close()

      it 'should say which', ->
        stats = request.get "http://#{hostname}:#{b_port}/json/which"
          .accept 'json'
        stats.then ({body}) ->
          debug body

      it 'should report statistics', ->
        stats = request.get "http://#{hostname}:#{b_port}/json/get_statistics"
          .query params: 'all,usrloc:location-users,net:,uri:'
          .accept 'json'
        stats.then ({body}) ->
          debug body
          body.should.have.property 'registrar:max_expires', '7200'
