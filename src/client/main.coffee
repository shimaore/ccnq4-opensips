zappa = require 'zappajs'
io = require 'socket.io-client'
LRU = require 'lru-cache'
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

  cfg.usrloc = LRU
    # Store at most 6000 entries
    max: 6000
    # For at most 24 hours
    maxAge: 24 * 3600 * 1000

  cfg.socket = io cfg.notify if cfg.notify?

  # Subscribe to the `locations` bus.
  cfg.socket?.on 'welcome', ->
    cfg.socket.emit 'configure', locations:true

  # Reply to requests for a single AOR.
  cfg.socket?.on 'location', (aor) ->
    doc = cfg.usrloc.get aor
    doc ?= _id:aor
    cfg.socket.emit 'location:response', doc

  # Reply to requests for all AORs.
  cfg.socket?.on 'locations', ->
    docs = {}
    cfg.usrloc.forEach (value,key) ->
      docs[key] = value
    cfg.socket.emit 'locations:response', docs

  # Ping
  cfg.socket?.on 'ping', (doc) ->
    cfg.socket.emit 'pong', host:hostname, in_reply_to:doc, name:pkg.name, version:pkg.version

  zappa_as_promised main, cfg

main = (cfg) ->

  ->
    @use morgan:'combined'

    # REST/JSON API

    @get '/', ->
      @json
        name: "#{pkg.name}:client"
        version: pkg.version

    # OpenSIPS db_http API (for locations only)

    @get '/location/': -> # usrloc_table

      if @query.k is 'username' and @query.op is '='
        doc = cfg.usrloc.get @query.v
        if doc?
          @res.type 'text/plain'
          @send show doc, @req, 'location'
        else
          @send ''
        return

      if @query.k is 'username,domain' and @query.op is '=,='
        [username,domain] = @query.v.split ','
        doc = cfg.usrloc.get "#{username}@#{domain}"
        if doc?
          @res.type 'text/plain'
          @send show doc, @req, 'location'
        else
          @send ''
        return

      if not @query.k? or (@query.k is 'username' and not @query.op?)
        rows = []
        cfg.usrloc.forEach (value,key) ->
          rows.push {key,value}
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

      doc.hostname ?= hostname
      doc.query_type = @body.query_type
      cfg.socket?.emit 'location:update', doc

      if @body.query_type is 'insert' or @body.query_type is 'update'

        @res.type 'text/plain'
        @send doc._id
        cfg.usrloc.set doc._id, doc
        return

      if @body.query_type is 'delete'

        @send ''
        cfg.usrloc.del doc._id
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
