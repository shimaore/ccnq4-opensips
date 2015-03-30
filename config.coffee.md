OpenSIPS script writer
----------------------

    module.exports = build_config = (local_config) ->

Configuration for the entire package.

      cfg = require local_config ? './local/config.json'
      assert cfg.opensips?, 'Missing `opensips` object in configuration.'
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
    if require.main is module

Build the configuration file.

      console.log "#{pkg.name} #{pkg.version} config -- Starting."
      options = build_config()
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
          supervisor.startProcessAsync 'dispatcher'
