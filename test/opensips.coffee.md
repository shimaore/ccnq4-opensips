    exec = require('exec-as-promised') console
    Promise = require 'bluebird'
    fs = Promise.promisifyAll require 'fs'
    request = (require 'superagent-as-promised') require 'superagent'

    @opensips = (port,cfg) ->
      fs.writeFileAsync "/tmp/config-#{port}", cfg
      .then ->
        exec "docker run --rm=true -v /tmp/config-#{port}:/tmp/config -p 127.0.0.1:#{port}:#{port} shimaore/opensips:1.11.1 /opt/opensips/sbin/opensips -f /tmp/config -m 1024 -M 256 -F -E"

    @kill = (port) ->
      request.get "http://127.0.0.1:#{port}/json/kill"
      .catch -> true
      return
