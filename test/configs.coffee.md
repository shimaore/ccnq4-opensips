    describe 'OpenSIPS', ->
      exec = require('exec-as-promised') console
      Promise = require 'bluebird'
      fs = Promise.promisifyAll require 'fs'
      zappa = require '../src/zappa-as-promised'
      request = require 'superagent-as-promised'
      {opensips,kill} = require './opensips'
      PouchDB = require 'pouchdb'

      it 'should log time', (done) ->
        @timeout 4000
        port = 7490
        a_port = port++
        b_port = port++
        main = ->
          @get '/time/:time', ->
            @params.time.should.match /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\+\d\d\d\d$/
            @json ok:yes
            kill b_port
            done()
        zappa (-> main), web: {host:'172.17.0.1', port:a_port}
        .then ->
          opensips b_port, """
            mpath="/opt/opensips/lib64/opensips/modules/"
            loadmodule "proto_udp.so"
            listen=udp:127.0.0.1:5911
            loadmodule "mi_json.so"

            loadmodule "httpd.so"
            modparam("httpd","port",#{b_port})
            loadmodule "rest_client.so"
            startup_route {
              $var(now) = $time(%FT%T%z);
              rest_get("http://172.17.0.1:#{a_port}/time/$var(now)","$var(body)");
              exit;
            }
          """
        Promise.delay 2500
        .then ->
          kill b_port
        return

      it 'should accept simple configuration', (done) ->
        @timeout 8000
        port = 7500
        a_port = port++
        b_port = port++
        main = ->
          @get '/', ->
            @json ok:yes
            kill b_port
            done()
        zappa (-> main), web: {host:'172.17.0.1', port:a_port}
        .then ->
          opensips b_port, """
            mpath="/opt/opensips/lib64/opensips/modules/"
            loadmodule "proto_udp.so"
            listen=udp:127.0.0.1:5909
            loadmodule "mi_json.so"

            loadmodule "httpd.so"
            modparam("httpd","port",#{b_port})
            loadmodule "rest_client.so"
            startup_route {
              rest_get("http://172.17.0.1:#{a_port}","$var(body)");
              exit;
            }
          """
        Promise.delay 2500
        .then ->
          kill b_port
        return

      it 'should parse JSON', (done) ->
        @timeout 8000
        port = 7510
        a_port = port++
        b_port = port++
        main = ->
          @get '/foo', ->
            @json foo:'bar'
          @get '/ok-json', ->
            @json ok:yes
            kill b_port
            done()
        zappa (-> main), web: {host:'172.17.0.1', port:a_port}
        .then ->

Notice: `rest_get(url,"$json(response)")` does not work, one must go through a variable.

          opensips b_port, """
            mpath="/opt/opensips/lib64/opensips/modules/"
            loadmodule "proto_udp.so"
            listen=udp:127.0.0.1:5910
            loadmodule "mi_json.so"

            loadmodule "json.so"
            loadmodule "httpd.so"
            modparam("httpd","port",#{b_port})
            loadmodule "rest_client.so"
            startup_route {
              if(rest_get("http://172.17.0.1:#{a_port}/foo","$var(body)")) {
                $json(response) := $var(body);
                if( $json(response/foo) == "bar") {
                  rest_get("http://172.17.0.1:#{a_port}/ok-json","$var(body)");
                }
              }
              exit;
            }
          """
        Promise.delay 2500
        .then ->
          kill b_port
        return

      it 'should accept `client` configuration', (done) ->

        @timeout 10000

        port = 7520
        a_port = port++
        b_port = port++
        c_port = port++
        success = false
        main = ->
          @get '/ok-client', ->
            @json ok:yes
            kill b_port
            done() unless success
            success = true

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config1.json'
        config.startup_route_code = """
            rest_get("http://172.17.0.1:#{a_port}/ok-client","$var(body)");
            exit;
        """
        config.httpd_port = b_port

        service = require '../src/client/main'
        config.db_url = "http://172.17.0.1:#{c_port}"

        zappa (-> main), web: {host:'172.17.0.1', port:a_port}
        .then ->
          service
            port: c_port
            host: '172.17.0.1'
            usrloc: 'location'
            usrloc_options: db: require 'memdown'
            web:
              port: c_port
              host: '172.17.0.1'
        .catch (error) ->
          console.log "Service error: #{error}"
        .then ->
          opensips b_port, compile config
        .catch (error) ->
          console.log "OpenSIPS error: #{error}"
        Promise.delay 2500
        .then ->
          kill b_port
        return

      it 'should accept `registrant` configuration', (done) ->

        @timeout 10000

        port = 27530
        a_port = port++
        b_port = port++
        c_port = port++
        main = ->
          @get '/ok-registrant', ->
            @json ok:yes
            kill b_port
            done()

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config2.json'
        config.startup_route_code = """
            rest_get("http://172.17.0.1:#{a_port}/ok-registrant","$var(body)");
            exit;
        """
        config.httpd_port = b_port

        service = require '../src/registrant/main'
        config.db_url = "http://172.17.0.1:#{c_port}"

        zappa (-> main), web: {host:'172.17.0.1', port:a_port}
        .then ->
          service
            port: c_port
            host: '172.17.0.1'
            prov: new PouchDB 'provisioning', db: require 'memdown'
            push: -> Promise.resolve()
            opensips:
              host: 'example.net'
            web:
              port: c_port
              host: '172.17.0.1'
        .catch (error) ->
          console.log "Service error: #{error}"
        .then ->
          opensips b_port, compile config
        .catch (error) ->
          console.log "OpenSIPS error: #{error}"
        Promise.delay 2500
        .then ->
          kill b_port
        return
