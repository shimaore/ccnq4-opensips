    describe 'OpenSIPS', ->
      exec = require('exec-as-promised') console
      Promise = require 'bluebird'
      fs = Promise.promisifyAll require 'fs'
      zappa = require 'zappajs'
      request = require 'superagent-as-promised'
      {opensips,kill} = require './opensips'
      PouchDB = require 'pouchdb'

      it 'should accept simple configuration', (done) ->
        port = 7500
        a_port = port++
        b_port = port++
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/', ->
            @json ok:yes
            kill b_port
            done()
        opensips b_port, """
          mpath="/opt/opensips/lib64/opensips/modules/"
          loadmodule "proto_udp.so"
          listen=udp:127.0.0.1:5909
          loadmodule "mi_json.so"

          loadmodule "httpd.so"
          modparam("httpd","port",#{b_port})
          loadmodule "rest_client.so"
          startup_route {
            rest_get("http://172.17.42.1:#{a_port}","$var(body)");
            exit;
          }
        """
        Promise.delay 1500
        .then ->
          kill b_port
        return

      it 'should parse JSON', (done) ->
        port = 7510
        a_port = port++
        b_port = port++
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/foo', ->
            @json foo:'bar'
          @get '/ok', ->
            @json ok:yes
            kill b_port
            done()

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
            if(rest_get("http://172.17.42.1:#{a_port}/foo","$var(body)")) {
              $json(response) := $var(body);
              if( $json(response/foo) == "bar") {
                rest_get("http://172.17.42.1:#{a_port}/ok","$var(body)");
              }
            }
            exit;
          }
        """
        Promise.delay 1500
        .then ->
          kill b_port
        return

      it 'should accept `client` configuration', (done) ->

        @timeout 3000

        port = 7520
        a_port = port++
        b_port = port++
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/ok', ->
            @json ok:yes
            kill b_port
            done()

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config1.json'
        config.startup_route_code = """
            rest_get("http://172.17.42.1:#{a_port}/ok","$var(body)");
            exit;
        """
        config.httpd_port = b_port

        service = require '../src/client/main'
        config.db_url = 'http://172.17.42.1:34340'
        service
          port: 34340
          host: '172.17.42.1'
          usrloc: 'location'
          usrloc_options: db: require 'memdown'
        .then ->
          opensips b_port, compile config
        .catch (error) ->
          console.log "Service error: #{error}"
        Promise.delay 1500
        .then ->
          kill b_port
        return

      it 'should accept `registrant` configuration', (done) ->

        @timeout 3000

        port = 7530
        a_port = port++
        b_port = port++
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/ok', ->
            @json ok:yes
            kill b_port
            done()

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config2.json'
        config.startup_route_code = """
            rest_get("http://172.17.42.1:#{a_port}/ok","$var(body)");
            exit;
        """
        config.httpd_port = b_port

        service = require '../src/registrant/main'
        config.db_url = 'http://172.17.42.1:34342'
        service
          port: 34342
          host: '172.17.42.1'
          prov: new PouchDB 'provisioning', db: require 'memdown'
        .then ->
          opensips b_port, compile config
        .catch (error) ->
          console.log "Service error: #{error}"
        Promise.delay 1500
        .then ->
          kill b_port
        return
