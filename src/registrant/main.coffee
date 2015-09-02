zappa = require 'zappajs'
PouchDB = require 'pouchdb'
pkg = require '../../package.json'
name = "#{pkg.name}:registrant"
debug = (require 'debug') name

{list} = require './opensips'
couchapp = require './couchapp'
zappa_as_promised = require '../zappa-as-promised'

module.exports = (cfg) ->

  cfg.push couchapp
  .then ->
    zappa_as_promised main, cfg

main = (cfg) ->

  debug 'Using configuration', cfg

  ->
    @use morgan:'combined'

    # REST/JSON API
    queries =
      version: 0
      registrant: 0

    @get '/', ->
      @json {
        name
        version: pkg.version
        queries
      }

    @get '/registrant/': ->
      queries.registrant++
      if not @query.k?
        cfg.prov.query "#{couchapp.id}/registrant_by_host",
          startkey: [cfg.opensips.host]
          endkey: [cfg.opensips.host,{}]
        .then ({rows}) =>
          @send list rows, @req, 'registrant'
        return

      @send ""

    @get '/version/': ->
      queries.version++
      if @query.k is 'table_name' and @query.c is 'table_version'

        versions =
          registrant: 1

        return "int\n#{versions[@query.v]}\n"

      @send ""
