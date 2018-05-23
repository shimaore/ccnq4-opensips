    assert = require 'assert'
    logger = require 'tangible'
    logger
      .use require 'tangible/cuddly'
      .use require 'tangible/gelf'
      .use require 'tangible/redis'
      .use require 'tangible/net'
    debug = logger "ccnq4-opensips:config"
    Nimble = require 'nimble-direction'
    ccnq4_config = require 'ccnq4-config'
    Options = require './config'
    opensips = require './opensips'

    module.exports = main = ->

      cfg = ccnq4_config()
      assert cfg?, 'Missing configuration.'

      logger.use (require 'tangible/repl') {cfg}
      await Nimble cfg

Build the configuration file.

      options = Options cfg
      (require './src/config/compiler') options

Replicate the provisioning database

      await cfg.reject_tombstones cfg.prov
      await cfg.reject_types cfg.prov
      await cfg.replicate 'provisioning'

      await run cfg

      opensips()

    if require.main is module
      main().catch (error) ->
        debug.dev "Failed to start with error #{error}", error.stack
        process.exit 1
