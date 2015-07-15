util = require 'util'
zappa = require 'zappajs'
PouchDB = require 'pouchdb'
pkg = require '../../package.json'
debug = (require 'debug') "#{pkg.name}:registrant"

{list} = require './opensips'
zappa_as_promised = require '../zappa-as-promised'

module.exports = (cfg) ->

  couchapp = require './couchapp'
  cfg.prov.get couchapp._id
  .catch -> {}
  .then ({_rev}) ->
    couchapp._rev = _rev if _rev?
    cfg.prov.put couchapp
  .then ->
    zappa_as_promised main, cfg

main = (cfg) ->

  debug 'Using configuration', cfg

  ->

    @get '/registrant/': ->
      if not @query.k?
        cfg.prov.query "#{pkg.name}-registrant/registrant_by_host",
          startkey: [cfg.host]
          endkey: [cfg.host,{}]
        .then ({rows}) =>
          @send list rows, @req, 'registrant'
        return

      util.error "registrant: not handled: #{@query.k}"
      @send ""

    @get '/version/': ->
      if @query.k is 'table_name' and @query.c is 'table_version'

        # Versions for OpenSIPS 1.11.0 FIXME
        versions =
          registrant: 1

        return "int\n#{versions[@query.v]}\n"

      util.error "version not handled: #{util.inspect @req}"
      @send ""
