    exec = require('exec-as-promised') console
    Promise = require 'bluebird'
    fs = Promise.promisifyAll require 'fs'
    request = (require 'superagent-as-promised') require 'superagent'

    pkg = require '../package.json'

    docker_opensips = pkg.opensips.version

    @opensips = (port,cfg) ->
      fs.writeFileAsync "/tmp/config-#{port}", cfg
      .then ->
        exec "docker run --rm=true -v /tmp/config-#{port}:/tmp/config -p 127.0.0.1:#{port}:#{port} shimaore/opensips:#{docker_opensips} /opt/opensips/sbin/opensips -f /tmp/config -m 1024 -M 256 -F -E"

    @kill = (port) ->
      request.get "http://127.0.0.1:#{port}/json/kill"
      .catch -> true
      return
