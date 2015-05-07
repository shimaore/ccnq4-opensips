OpenSIPS / CouchDB data proxy
-----------------------------

    run = ->

The OpenSIPS parameters.

      config = Config process.env.CONFIG

      db_url = url.parse config.db_url

The service (database proxy) parameters.

      cfg = require './local/config.json'

      cfg.port ?= db_url.port
      cfg.host ?= db_url.hostname

      type = switch config.model
        when 'registrant'
          'registrant'
        else
          'client'

      service = require "./src/#{type}/main"
      service cfg
      .then ({server}) ->
        debug 'Server ready'
        server.on 'listening', ->
          debug 'Server listening'

If there was an issue with the server,

      .catch (error) ->

log it,

        console.log "Service error: #{error}"

and ask supervisord to restart us.

        throw error

    url = require 'url'
    pkg = require './package.json'
    debug = (require 'debug') "#{pkg.name}:data"
    Config = require './config'
    if require.main is module
      run()
    else
      module.exports = run
