OpenSIPS script writer
----------------------

    module.exports = build_config = ->

Configuration for the entire package.

      cfg = require './local/config.json'
      assert cfg.opensips?, 'Missing `opensips` object in configuration.'
      assert cfg.opensips.model?, 'Missing `model` field in `opensips` object in configuration.'

Use `default.json` as the base.

      options = require "./src/config/default.json"

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
      console.log "#{pkg.name} #{pkg.version} config -- Starting."
      (require './src/config/compiler') build_config()
