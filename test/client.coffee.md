    chai = require 'chai'
    chai.should()

    describe 'The `client` configuration', ->
      zappa = require 'zappajs'
      request = require 'superagent-as-promised'
      Promise = require 'bluebird'
      {opensips,kill} = require './opensips'

      port = 7600
      a_port = port++
      b_port = port++

      our_server = null

      before (done) ->
        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config './test/config1.json'
        config.httpd_port = b_port

        service = require '../src/client/main'
        config.db_url = 'http://172.17.42.1:34344'
        our_server = service
          port: 34344
          host: '172.17.42.1'
          usrloc: 'location'
          usrloc_options: db: require 'memdown'
        .then ({server}) ->
          console.log "Server ready"
          server.on 'listening', ->
            console.log "Server listening"
            opensips b_port, compile config
            Promise.delay 600
            .then -> done()
        .catch (error) ->
          console.log "Service error: #{error}"

      after ->
        kill b_port

      it 'should report statistics', ->
        stats = request.get "http://127.0.0.1:#{b_port}/json/get_statistics"
          .query params: 'all,usrloc:location-users,net:,uri:'
          .accept 'json'
        stats.then ({body}) ->
          console.dir body
          body.should.have.property 'registrar:max_expires', '7200'
