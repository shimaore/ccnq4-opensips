    exec = require('exec-as-promised') console
    Promise = require 'bluebird'
    fs = Promise.promisifyAll require 'fs'
    request = require 'superagent'

    pkg = require '../package.json'

    docker_opensips = 'v4.4.5'

    @opensips = (port,cfg) ->
      fs.writeFileAsync "/tmp/config-#{port}", cfg
      .then ->
        exec "docker run --rm=true -v /tmp/config-#{port}:/tmp/config -p 127.0.0.1:#{port}:#{port} shimaore/docker.opensips:#{docker_opensips} /opt/opensips/sbin/opensips -f /tmp/config -m 64 -M 32 -F -E"

    @kill = (port) ->
      request.get "http://127.0.0.1:#{port}/json/kill"
      .catch -> true
