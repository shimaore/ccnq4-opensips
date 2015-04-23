OpenSIPS script writer
----------------------

    module.exports = build_config = (local_config) ->

Configuration for the entire package.

      cfg = try require local_config ? './local/config.json'
      cfg ?= {}
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
    Promise = require 'bluebird'
    assert = require 'assert'
    if require.main is module

Build the configuration file.

      console.log "#{pkg.name} #{pkg.version} config -- Starting."
      options = build_config process.env.LOCAL_CONFIG ? null
      (require './src/config/compiler') options

Start the data server.

      supervisord = require 'supervisord'
      supervisor = Promise.promisifyAll supervisord.connect 'http://127.0.0.1:5708'
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
            cert_paths = local

          """
          fs = require 'fs'
          fs.writeFileSync 'vendor/mediaproxy-2.6.1/config.ini', mp_config
          supervisor.startProcessAsync 'dispatcher'
