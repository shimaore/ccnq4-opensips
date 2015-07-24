zappa = require 'zappajs'
io = require 'socket.io-client'
PouchDB = require 'pouchdb'
Promise = require 'bluebird'
pkg = require '../../package.json'
debug = (require 'debug') "#{pkg.name}:client"
body_parser = require 'body-parser'

make_id = (t,n) -> [t,n].join ':'

{show,list} = require './opensips'
{unquote_params} = require '../quote'
zappa_as_promised = require '../zappa-as-promised'
hostname = (require 'os').hostname()

module.exports = (cfg) ->
  debug 'Using configuration', cfg

  # If no `usrloc` URI is provided, use a local (LevelDB) registrar DB.
  cfg.usrloc = new PouchDB cfg.usrloc ? "location", cfg.usrloc_options ? {}
  cfg.socket = io cfg.notify if cfg.notify?

  zappa_as_promised main, cfg

main = (cfg) ->

  ->

    # REST/JSON API

    @get '/', ->
      @json
        name: "#{pkg.name}:client"
        version: pkg.version

    @get '/location/:username', ->
      usrloc.get @param.username
      .then (doc) ->
        @json doc
      , (error) ->
        @res.status(404).json error: "#{error}"

    # OpenSIPS db_http API (for locations only)

    @get '/location/': -> # usrloc_table

      if @query.k is 'username' and @query.op is '='
        usrloc.get @query.v
        .then (doc) =>
          @res.type 'text/plain'
          @send show doc, @req, 'location'
        return

      if @query.k is 'username,domain' and @query.op is '=,='
        [username,domain] = @query.v.split ','
        cfg.usrloc.get "#{username}@#{domain}"
        .then (doc) =>
          @res.type 'text/plain'
          @send show doc, @req, 'location'
        return

      if not @query.k? or (@query.k is 'username' and not @query.op?)
        cfg.usrloc.allDocs include_docs:true
        .then ({rows}) =>
          @res.type 'text/plain'
          @send list rows, @req, 'location'
        return

      console.error "location: not handled: #{@query.k} #{@query.op} #{@query.v}"
      @send ""

    @post '/location', (body_parser.urlencoded extended:false), ->

      doc = unquote_params(@body.k,@body.v,'location')
      # Note: this allows for easy retrieval, but only one location can be stored.
      # Use "callid" as an extra key parameter otherwise.
      doc._id = "#{doc.username}@#{doc.domain}"

      if @body.uk?
        update_doc = unquote_params(@body.uk,@body.uv,'location')
        doc[k] = v for k,v of update_doc

      doc.query_data =
        hostname: hostname
        type: @body.query_type
      cfg.socket?.emit 'location', doc

      if @body.query_type is 'insert' or @body.query_type is 'update'

        cfg.usrloc.get doc._id
        .catch ->
          {}
        .then ({_rev}) =>
          doc._rev = _rev if _rev?
          cfg.usrloc.put doc
        .then =>
          @res.type 'text/plain'
          @send doc._id
        .catch (error) ->
          console.error "location: error updating #{doc._id}: #{error}"
          @send ''
        return

      if @body.query_type is 'delete'

        cfg.usrloc.get doc._id
        .catch ->
          {}
        .then ({_rev}) =>
          if not _rev? then return
          doc._rev = _rev
          cfg.usrloc.remove doc
        .catch (error) ->
          console.error "location: error deleting #{doc._id}: #{error}"
        .then =>
          @send ''
        return

      util.error "location: not handled: #{util.inspect @req}"
      @send ""

    @get '/version/': ->
      if @query.k is 'table_name' and @query.c is 'table_version'

        # Versions for OpenSIPS 1.11.0 FIXME
        versions =
          location: 1009

        return "int\n#{versions[@query.v]}\n"

      util.error "version not handled: #{util.inspect @req}"
      @send ""
