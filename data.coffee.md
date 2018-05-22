OpenSIPS / CouchDB data proxy
-----------------------------

    run = (cfg) ->

The service (database proxy) parameters.

* cfg.web.port Port for the web service that interfaces with OpenSIPS. Default: port of cfg.opensips.db_url.
* cfg.web.host Hostname for the web service that interfaces with OpenSIPS. Default: hostname of cfg.opensips.db_url.

      db_url = url.parse cfg.opensips.db_url
      cfg.web ?= {}
      cfg.web.port ?= db_url.port
      cfg.web.host ?= db_url.hostname

cfg.opensips.model Model for OpenSIPS configuration; either `client` (the default) or `registrant`.

      type = switch cfg.opensips.model
        when 'registrant'
          'registrant'
        else
          'client'

      service = require "./src/#{type}/main"
      await service cfg

Registrant reload on data changes.

* cfg.httpd_ip Hostname for OpenSIPS' HTTPD server. Default: '127.0.0.1'.
* cfg.httpd_port Port number for OpenSIPS' HTTPD server. Default: 8560.

      if type is 'registrant'
        RoyalThing ->
          ip = cfg.httpd_ip ? '127.0.0.1'
          port = cfg.httpd_port ? 8560
          request
          .get "http://#{ip}:#{port}/json/reg_reload"
          .accept 'json'
          .then ->
            debug "Registrant reload requested"

      munin = require './src/munin'
      munin cfg

    url = require 'url'
    logger = require 'tangible'
    logger
      .use require 'tangible/cuddly'
      .use require 'tangible/gelf'
      .use require 'tangible/redis'
    debug = logger "ccnq4-opensips:data"
    RoyalThing = require 'royal-thing'
    request = require 'superagent'
