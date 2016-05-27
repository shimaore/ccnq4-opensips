    pkg = require './package.json'
    replication_filter_doc = require 'nimble-direction/replication_filter_doc'

    replicate_types = [
      'carrier'
      'config'
      'domain'
      # 'emergency
      'endpoint'
      # 'gateway'
      'host'
      'list'
      # 'location
      'number'
      'number_domain'
      # 'rule'    # No longer in provisioning
      # 'ruleset'
    ]

    @couch = replication_filter_doc pkg, replicate_types
