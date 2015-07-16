OpenSIPS / CouchDB data proxy
-----------------------------

    run = (cfg) ->

The service (database proxy) parameters.

      db_url = url.parse cfg.opensips.db_url
      cfg.port ?= db_url.port
      cfg.host ?= db_url.hostname

      type = switch config.model
        when 'registrant'
          'registrant'
        else
          'client'

      service = require "./src/#{type}/main"
      service cfg
      .then ->
        debug 'Service ready'

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
          .catch (error) ->
            debug "Stop opensips: #{error}"
            null
          .then ->
            supervisor.startProcessAsync 'opensips'
          .catch (error) ->
            debug "Start opensips: #{error}"

    url = require 'url'
    pkg = require './package.json'
    debug = (require 'debug') "#{pkg.name}:data"
    RoyalThing = require 'royal-thing'
    supervisord = require 'supervisord'
    Promise = require 'bluebird'
    Nimble = require 'nimble-direction'
    Options = require './config'
    assert = require 'assert'

    module.exports = run

    if require.main is module
      debug "#{pkg.name} #{pkg.version} data -- Starting."
      assert process.env.CONFIG?, 'Missing CONFIG environment.'
      assert process.env.SUPERVISOR?, 'Missing SUPERVISOR environment.'

      cfg = require process.env.CONFIG

      Nimble cfg
      .then ->
        Options cfg
        run cfg
      .then ->
        debug "Started."
