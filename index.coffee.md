    pkg = require './package.json'
    replication_filter_doc = require 'nimble-direction/replication_filter_doc'

    replicate_types = [
      'carrier'
      'config'
      'domain'
      'destination' # ?
      # 'emergency
      'endpoint'
      # 'gateway'
      'host'
      'list'
      # 'location
      'number'
      # 'rule'
      # 'ruleset'
    ]

    @couch = replication_filter_doc pkg, replicate_types
