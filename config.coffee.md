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

      # debug 'Using configuration', cfg
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

    assert = require 'assert'
    logger = require 'tangible'
    debug = logger "ccnq4-opensips:config"
    os = require 'os'

    module.exports = Options
