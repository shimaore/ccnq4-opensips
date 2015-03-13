OpenSIPS / CouchDB data proxy
-----------------------------

    run = ->
      config = (require './config')()

      db_url = url.parse config.db_url

      cfg = require './local/config.json'

      cfg.port ?= db_url.port
      cfg.host ?= db_url.host

      type = switch config.model
        when 'registrant'
          'registrant'
        else
          'client'

      mod = require "./src/#{type}/main"
      mod cfg
      # .then
      # .catch

    url = require 'url'
    run()
