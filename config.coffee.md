OpenSIPS script writer
----------------------

    Options = (cfg) ->

Configuration for the entire package.

      cfg.opensips ?= {}

      cfg_env =
        model: 'MODEL'
        runtime_opensips_cfg: 'CFG'
        sip_domain_name: 'DOMAIN'
        proxy_ip: 'PROXY_IP'
        source_ip: 'SOURCE_IP'
        local_ipv4: 'LOCAL_IPV4'

      for k,v of cfg_env
        cfg.opensips[k] ?= process.env[v] if process.env[v]?

      debug 'Using configuration', cfg
      assert cfg.opensips.model?, 'Missing `model` field in `opensips` object in configuration.'

      options = {}

Use `default.json` as the base.

      defaults = require "./src/config/default.json"
      for own k,v of defaults
        options[k] = v

Override it with any configuration element found in the model.

      model = require "./src/#{cfg.opensips.model}/config.json"
      for own k,v of model
        options[k] = v

Override them with any configuration elment found in the configuration's `opensips` object.

      for own k,v of cfg.opensips
        options[k] = v

      options.__hostname = cfg.host ? os.hostname()

      cfg.opensips = options

      options

Toolbox
-------

    pkg = require './package.json'
    assert = require 'assert'
    logger = require 'tangible'
    logger
      .use require 'tangible/cuddly'
      .use require 'tangible/gelf'
      .use require 'tangible/redis'
    debug = logger "#{pkg.name}:config"
    Promise = require 'bluebird'
    supervisord = require 'supervisord'
    fs = Promise.promisifyAll require 'fs'
    os = require 'os'
    Nimble = require 'nimble-direction'
    seem = require 'seem'
    Couch = require './index'

    module.exports = Options

    main = seem ->

      debug "#{pkg.name} #{pkg.version} config -- Starting."
      assert process.env.CONFIG?, 'Missing CONFIG environment.'
      assert process.env.SUPERVISOR?, 'Missing SUPERVISOR environment.'

      cfg = require process.env.CONFIG

      yield Nimble cfg

Build the configuration file.

      options = Options cfg
      (require './src/config/compiler') options

Replicate the provisioning database

      couch = Couch cfg.opensips.model
      yield cfg.master_push couch
      yield cfg.reject_tombstones cfg.prov
      yield cfg.replicate 'provisioning', (doc) ->
          debug "Using replication filter #{couch.replication_filter}"
          doc.filter = couch.replication_filter
          doc.comment += " for #{pkg.name}"

Start the data server.

      supervisor = Promise.promisifyAll supervisord.connect process.env.SUPERVISOR
      yield supervisor.startProcessAsync 'data'
      debug 'Started data server'
      unless cfg.server_only is true
        yield supervisor.startProcessAsync 'opensips'
        debug 'Started opensips'

      debug "Started."

    if require.main is module
      main()
      .catch (error) ->
        debug "Startup failed: #{error}"
