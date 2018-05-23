    assert = require 'assert'
    logger = require 'tangible'
    logger
      .use require 'tangible/cuddly'
      .use require 'tangible/gelf'
      .use require 'tangible/redis'
      .use require 'tangible/net'
    debug = logger "ccnq4-opensips:server"
    Nimble = require 'nimble-direction'
    ccnq4_config = require 'ccnq4-config'
    Options = require './config'
    run = require './data'
    opensips = require './opensips'

    module.exports = main = ->

      cfg = ccnq4_config()
      assert cfg?, 'Missing configuration.'

      logger.use (require 'tangible/repl') {cfg}
      await Nimble cfg

      debug 'Build the configuration file.'

      options = Options cfg
      (require './src/config/compiler') options

      debug 'Replicate the provisioning database.'

      await cfg.reject_tombstones cfg.prov
      await cfg.reject_types cfg.prov
      unless await cfg.replicate 'provisioning'
        throw new Error 'Unable to start the replication of the provisioning database.'

      debug 'Start the data server'

      await run cfg

      debug 'Start OpenSIPS'

      opensips()

    if require.main is module
      main().catch (error) ->
        debug.dev "Failed to start with error #{error}", error.stack
        process.exit 1
