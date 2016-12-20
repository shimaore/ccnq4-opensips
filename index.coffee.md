    pkg = require './package.json'
    replication_filter_doc = require 'nimble-direction/replication_filter_doc'

    replicate_types =

Used by the `client` profile:

      client: [
        'endpoint'
        'number_domain'
      ]

Used by the `registrant` profile (see src/registrant/couchapp.coffee):

      registrant: [
        'host'
        'number'
      ]

    module.exports = Couch = (model) ->
      replication_filter_doc pkg, replicate_types[model]
