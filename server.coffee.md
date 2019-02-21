    assert = require 'assert'
    logger = require 'tangible'
    debug = logger "ccnq4-opensips:server"
    Nimble = require 'nimble-direction'
    CouchDB = require 'most-couchdb/with-update'
    ccnq4_config = require 'ccnq4-config'
    Options = require './config'
    run = require './data'
    opensips = require './opensips'

    module.exports = main = ->

      cfg = ccnq4_config()
      assert cfg?, 'Missing configuration.'

      nimble = await Nimble cfg
      prov = new CouchDB nimble.provisioning

      debug 'Build the configuration file.'

      options = Options cfg
      (require './src/config/compiler') options

      debug 'Replicate the provisioning database.'

      await nimble.reject_tombstones prov
      await nimble.reject_types prov
      unless await nimble.replicate 'provisioning'
        throw new Error 'Unable to start the replication of the provisioning database.'

      debug 'Start the data server'

      await run cfg

      debug 'Start OpenSIPS'

      opensips()

    if require.main is module
      main().catch (error) ->
        debug.dev "Failed to start with error #{error}", error.stack
        process.exit 1
