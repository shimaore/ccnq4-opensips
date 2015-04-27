OpenSIPS / CouchDB data proxy
-----------------------------

    run = ->

The OpenSIPS parameters.

      config = (require './config')()

      db_url = url.parse config.db_url

The service (database proxy) parameters.

      cfg = require './local/config.json'

      cfg.port ?= db_url.port
      cfg.host ?= db_url.host

      type = switch config.model
        when 'registrant'
          'registrant'
        else
          'client'

      service = require "./src/#{type}/main"
      service cfg
      .then ({server}) ->
        server.on 'listening', ->
          opensips b_port, compile config
      .catch (error) ->
        console.log "Service error: #{error}"

    url = require 'url'
    run()
