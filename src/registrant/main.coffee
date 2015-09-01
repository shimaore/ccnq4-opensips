zappa = require 'zappajs'
PouchDB = require 'pouchdb'
pkg = require '../../package.json'
name = "#{pkg.name}:registrant"
debug = (require 'debug') name

{list} = require './opensips'
zappa_as_promised = require '../zappa-as-promised'

module.exports = (cfg) ->

  couchapp = require './couchapp'
  cfg.push couchapp
  .then ->
    zappa_as_promised main, cfg

main = (cfg) ->

  debug 'Using configuration', cfg

  ->
    @use morgan:'combined'

    # REST/JSON API

    @get '/', ->
      @json {
        name
        version: pkg.version
      }

    @get '/registrant/': ->
      if not @query.k?
        cfg.prov.query "#{pkg.name}-registrant/registrant_by_host",
          startkey: [cfg.opensips.host]
          endkey: [cfg.opensips.host,{}]
        .then ({rows}) =>
          @send list rows, @req, 'registrant'
        return

      @send ""

    @get '/version/': ->
      if @query.k is 'table_name' and @query.c is 'table_version'

        # Versions for OpenSIPS 1.11.0 FIXME
        versions =
          registrant: 1

        return "int\n#{versions[@query.v]}\n"

      @send ""
