OpenSIPS script writer
----------------------

    module.exports = Options = (cfg) ->

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

      options

Toolbox
-------

    pkg = require './package.json'
    assert = require 'assert'
    debug = (require 'debug') "#{pkg.name}:config"
    Promise = require 'bluebird'
    supervisord = require 'supervisord'
    fs = Promise.promisifyAll require 'fs'
    Nimble = require 'nimble-direction'

    if require.main is module

      debug "#{pkg.name} #{pkg.version} config -- Starting."
      assert process.env.CONFIG?, 'Missing CONFIG environment.'
      assert process.env.SUPERVISOR?, 'Missing SUPERVISOR environment.'

      cfg = require process.env.CONFIG

      Nimble cfg
      .then ->

Build the configuration file.

        options = Options cfg
        (require './src/config/compiler') options

Start the data server.

        supervisor = Promise.promisifyAll supervisord.connect process.env.SUPERVISOR
        supervisor.startProcessAsync 'data'
      .then ->
        supervisor.startProcessAsync 'opensips'
      .then ->

This is kind of an ad-hoc test, but it should be consistent with our use of MediaProxy.

        if 'mediaproxy' in options.recipe
          mp_config = """
            [Dispatcher]
            socket_path = #{options.var_run_mediaproxy}/dispatcher.sock
            passport = #{process.env.PASSPORT ? 'None'}
            listen = 0.0.0.0:25060
            listen_management = 127.0.0.1:25061
            management_use_tls = no
            log_level = DEBUG
            [TLS]
            cert_paths = #{process.env.CERT_PATHS ? '/home/opensips/local'}

          """
          debug 'Writing dispatcher configuration'
          fs.writeFileAsync "/home/opensips/vendor/mediaproxy-#{pkg.mediaproxy.version}/config.ini", mp_config
          .then ->
            debug 'Starting dispatcher'
            supervisor.startProcessAsync 'dispatcher'

      .then ->
        debug "Started."
