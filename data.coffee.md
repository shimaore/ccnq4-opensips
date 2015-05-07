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

        debug "Service error: #{error}"

and ask supervisord to restart us.

        throw error

Registrant reload on data changes.

      if type is 'registrant'
        RoyalThing ->
          supervisor = null
          Promise.resolve()
          .then ->
            supervisor = Promise.promisifyAll supervisord.connect process.env.SUPERVISOR
          .then ->
            supervisor.stopProcessAsync 'opensips'
          .then ->
            supervisor.startProcessAsync 'opensips'
          .catch (error) ->
            debug "Restarting opensips: #{error}"


    url = require 'url'
    pkg = require './package.json'
    debug = (require 'debug') "#{pkg.name}:data"
    Config = require './config'
    RoyalThing = require 'royal-thing'
    supervisord = require 'supervisord'
    Promise = require 'bluebird'
    if require.main is module
      run()
    else
      module.exports = run
