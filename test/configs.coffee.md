    (require 'chai').should()

    exec = require('exec-as-promised') console
    Express = require 'express'
    request = require 'superagent'
    {opensips,kill} = require './opensips'
    PouchDB = require 'ccnq4-pouchdb'
      .plugin require 'pouchdb-adapter-memory'
      .defaults adapter: 'memory'

    describe 'OpenSIPS', ->
      random = (n) ->
        n + Math.ceil 100 * Math.random()

      sleep = (timeout) -> new Promise (resolve) -> setTimeout resolve, timeout

      it 'should log time', ->
        our_server = null
        after ->
          @timeout 5000
          await sleep 1000
          await kill b_port
          await sleep 2000
          our_server.close()
        @timeout 8000
        port = random 7000
        a_port = port++
        b_port = port++
        c_port = port++
        app = Express()
        p = new Promise (done) ->
          app.get '/time/:time', (req,res) ->
              {time} = req.params
              time.should.match /^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d\+\d\d\d\d$/
              res.json ok:yes
              done()
        await new Promise (resolve) ->
          our_server = app.listen a_port, '172.17.0.1', resolve

        opensips b_port, """
          mpath="/opt/opensips/lib64/opensips/modules/"
          loadmodule "proto_udp.so"
          listen=udp:127.0.0.1:#{c_port}
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
        await p

      it 'should accept simple configuration', ->
        our_server = null
        after ->
          @timeout 5000
          await sleep 1000
          await kill b_port
          await sleep 2000
          our_server.close()
        @timeout 8000
        port = random 8000
        a_port = port++
        b_port = port++
        c_port = port++
        app = Express()
        p = new Promise (done) ->
          app.get '/', (req,res) ->
            res.json ok:yes
            done()
        await new Promise (resolve) ->
          our_server = app.listen a_port, '172.17.0.1', resolve

        opensips b_port, """
            mpath="/opt/opensips/lib64/opensips/modules/"
            loadmodule "proto_udp.so"
            listen=udp:127.0.0.1:#{c_port}
            loadmodule "mi_json.so"

            loadmodule "httpd.so"
            modparam("httpd","port",#{b_port})
            loadmodule "rest_client.so"
            startup_route {
              rest_get("http://172.17.0.1:#{a_port}","$var(body)");
              exit;
            }
          """
        await p

      it 'should parse JSON', ->
        our_server = null
        after ->
          @timeout 5000
          await sleep 1000
          await kill b_port
          await sleep 2000
          our_server.close()
        @timeout 8000
        port = random 9000
        a_port = port++
        b_port = port++
        c_port = port++
        app = Express()
        app.get '/foo', (req,res) ->
          res.json foo:'bar'
        p = new Promise (done) ->
          app.get '/ok-json', (req,res) ->
            res.json ok:yes
            done()
        await new Promise (resolve) ->
          our_server = app.listen a_port, '172.17.0.1', resolve

Notice: `rest_get(url,"$json(response)")` does not work, one must go through a variable.

        opensips b_port, """
            mpath="/opt/opensips/lib64/opensips/modules/"
            loadmodule "proto_udp.so"
            listen=udp:127.0.0.1:#{c_port}
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
        await p

      it 'should accept `client` configuration', ->
        our_server = null
        their_server = null
        after ->
          @timeout 5000
          await sleep 1000
          await kill b_port
          await sleep 2000
          our_server.close()
          their_server.close()

        @timeout 10000
        port = random 10000
        a_port = port++
        b_port = port++
        c_port = port++

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config1.json'
        config.startup_route_code = """
            rest_get("http://172.17.0.1:#{a_port}/ok-client","$var(body)");
            exit;
        """
        config.httpd_ip = ''
        config.httpd_port = b_port

        service = require '../src/client/main'
        config.db_url = "http://172.17.0.1:#{c_port}"

        app = Express()
        success = false
        p = new Promise (done) ->
          app.get '/ok-client', (req,res) ->
            res.json ok:yes
            done() unless success
            success = true
        await new Promise (resolve) ->
          our_server = app.listen a_port, '172.17.0.1', resolve

        their_server = await service
          port: c_port
          host: '172.17.0.1'
          usrloc: 'location'
          usrloc_options: db: require 'memdown'
          web:
            port: c_port
            host: '172.17.0.1'
        opensips b_port, compile config
        await p

      it 'should accept `registrant` configuration', ->
        our_server = null
        their_server = null
        after ->
          @timeout 5000
          await sleep 1000
          await kill b_port
          await sleep 2000
          our_server.close()
          their_server.close()
        @timeout 10000

        port = random 11000
        a_port = port++
        b_port = port++
        c_port = port++

        build_config = require '../config'
        {compile} = require '../src/config/compiler'
        config = build_config require './config2.json'
        config.startup_route_code = """
            rest_get("http://172.17.0.1:#{a_port}/ok-registrant","$var(body)");
            exit;
        """
        config.httpd_ip = ''
        config.httpd_port = b_port

        service = require '../src/registrant/main'
        config.db_url = "http://172.17.0.1:#{c_port}"

        prov = new PouchDB 'provisioning'

        app = Express()
        p = new Promise (done) ->
          app.get '/ok-registrant', (req,res) ->
            res.json ok:yes
            done()
        await new Promise (resolve) ->
          our_server = app.listen a_port, '172.17.0.1', resolve

        await prov.put (require '../src/registrant/couchapp') {}
        their_server = await service
            port: c_port
            host: '172.17.0.1'
            prov: prov
            push: -> Promise.resolve()
            opensips:
              host: 'example.net'
            web:
              port: c_port
              host: '172.17.0.1'
        opensips b_port, compile config
        await p
