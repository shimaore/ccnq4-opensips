zappa = require 'zappajs'
PouchDB = require 'pouchdb'
Promise = require 'bluebird'

make_id = (t,n) -> [t,n].join ':'

{show,list} = require './opensips'
{unquote_params} = require '../quote'
zappa_as_promised = require '../zappa-as-promised'

module.exports = (cfg) ->
  cfg.usrloc = new PouchDB cfg.usrloc ? "http://127.0.0.1:5984/location", cfg.usrloc_options
  cfg.port ?= 34340
  cfg.host ?= '127.0.0.1'

  zappa_as_promised main, cfg

main = (cfg) ->

  ->

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

    @post '/location', ((require 'body-parser').urlencoded extended:false), ->

      doc = unquote_params(@body.k,@body.v,'location')
      # Note: this allows for easy retrieval, but only one location can be stored.
      # Use "callid" as an extra key parameter otherwise.
      doc._id = "#{doc.username}@#{doc.domain}"

      if @body.uk?
        update_doc = unquote_params(@body.uk,@body.uv,'location')
        doc[k] = v for k,v of update_doc

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
          cfg.usrloc.delete doc
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
