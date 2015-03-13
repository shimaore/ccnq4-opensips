util = require 'util'

{list} = require './opensips'

module.exports = (cfg) ->
  assert cfg.host?, 'Missing `host` in configuration.'
  provisioning = new PouchBD cfg.provisioning ? 'http://127.0.0.1:5984/provisioning'
  cfg.port ?= 34340
  cfg.host ?= '127.0.0.1'

  couchapp = require './couchapp'
  provisioning.get couchapp._id
  .then ({_rev}) ->
    couchapp._rev = _rev if _rev?
    provisioning.put couchapp
  .then ->
    main cfg

main = (cfg) ->
  zappa = require 'zappajs'
  zappa cfg.port, cfg.host, io:no, ->

    @use 'bodyParser'

    @get '/registrant/': ->
      if not @query.k?
        cfg.provisioning.query "#{pkg.name}-registrant/registrant_by_host",
          startkey: [config.host]
          endkey: [config.host,{}]
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
