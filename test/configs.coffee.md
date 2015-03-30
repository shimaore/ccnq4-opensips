    describe 'OpenSIPS', ->
      exec = require('exec-as-promised') console
      Promise = require 'bluebird'
      fs = Promise.promisifyAll require 'fs'
      zappa = require 'zappajs'
      request = require 'superagent-as-promised'

      opensips = (port,cfg) ->
        fs.writeFileAsync "/tmp/config-#{port}", cfg
        .then ->
          exec "docker run --rm -v /tmp/config-#{port}:/tmp/config -p 127.0.0.1:#{port}:#{port} shimaore/opensips:1.11.1 /opt/opensips/sbin/opensips -f /tmp/config -m 1024 -M 256 -F -E"


      it 'should accept simple configuration', (done) ->
        port = 7500
        a_port = port++
        b_port = port++
        kill = ->
          request.get "http://127.0.0.1:#{b_port}/json/kill"
          .catch -> true
          return
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/', ->
            @json ok:yes
            kill()
            done()
        opensips b_port, """
          mpath="/opt/opensips/lib64/opensips/modules/"
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
          kill()
        return

      it 'should parse JSON', (done) ->
        port = 7510
        a_port = port++
        b_port = port++
        kill = ->
          request.get "http://127.0.0.1:#{b_port}/json/kill"
          .catch -> true
          return
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/foo', ->
            @json foo:'bar'
          @get '/ok', ->
            @json ok:yes
            kill()
            done()

Notice: `rest_get(url,"$json(response)")` does not work, one must go through a variable.

        opensips b_port, """
          mpath="/opt/opensips/lib64/opensips/modules/"
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
          kill()
        return

      it 'should accept `client` configuration', (done) ->

        port = 7520
        a_port = port++
        b_port = port++
        kill = ->
          request.get "http://127.0.0.1:#{b_port}/json/kill"
          .catch -> true
          return
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/ok', ->
            @json ok:yes
            kill()
            done()

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config './test/config1.json'
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
        .then ({server}) ->
          server.on 'listening', ->
            opensips b_port, compile config
        .catch (error) ->
          console.log "Service error: #{error}"
        Promise.delay 1500
        .then ->
          kill()
        return

      it 'should accept `registrant` configuration', (done) ->

        port = 7530
        a_port = port++
        b_port = port++
        kill = ->
          request.get "http://127.0.0.1:#{b_port}/json/kill"
          .catch -> true
          return
        zappa '172.17.42.1', a_port, io:no, ->
          @get '/ok', ->
            @json ok:yes
            kill()
            done()

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config './test/config2.json'
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
          provisioning: 'provisioning'
          provisioning_options: db: require 'memdown'
        .then ({server}) ->
          server.on 'listening', ->
            opensips b_port, compile config
        .catch (error) ->
          console.log "Service error: #{error}"
        Promise.delay 1500
        .then ->
          kill()
        return
