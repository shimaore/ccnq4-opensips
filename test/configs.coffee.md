    describe 'OpenSIPS', ->
      exec = require('exec-as-promised') console
      Promise = require 'bluebird'
      fs = Promise.promisifyAll require 'fs'
      zappa = require 'zappajs'
      request = require 'superagent-as-promised'

      opensips = (port,cfg) ->
        fs.writeFileAsync '/tmp/config', cfg
        .then ->
          exec "docker run --rm -v /tmp/config:/tmp/config -p 127.0.0.1:#{port}:#{port} shimaore/opensips:1.11.1 /opt/opensips/sbin/opensips -f /tmp/config -m 1024 -M 256 -F -E"


      it 'should accept simple configuration', (done) ->
        port = 7500
        a_port = port++
        b_port = port++
        zappa '172.17.42.1', a_port, ->
          @get '/', ->
            @json ok:yes
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
          request.get "http://127.0.0.1:#{b_port}/json/kill"
          .catch -> true
        return

      it 'should parse JSON', (done) ->
        port = 7510
        a_port = port++
        b_port = port++
        zappa '172.17.42.1', a_port, ->
          @get '/foo', ->
            @json foo:'bar'
          @get '/ok', ->
            @json ok:yes
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
          request.get "http://127.0.0.1:#{b_port}/json/kill"
          .catch -> true
        return

      it 'should accept complete configuration', (done) ->
        port = 7520
        a_port = port++
        b_port = port++
        zappa '172.17.42.1', a_port, ->
          @get '/ok', ->
            @json ok:yes
            done()

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config './test/config1.json'
        config.startup_route_code = """
            rest_get("http://172.17.42.1:#{a_port}/ok","$var(body)");
        """

        opensips b_port, compile config
        Promise.delay 1500
        .then ->
          request.get "http://127.0.0.1:#{b_port}/json/kill"
          .catch -> true
        return
