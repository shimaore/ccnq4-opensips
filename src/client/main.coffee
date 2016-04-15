zappa = require 'zappajs'
io = require 'socket.io-client'
LRU = require 'lru-cache'
Promise = require 'bluebird'
pkg = require '../../package.json'
name = "#{pkg.name}:client"
debug = (require 'debug') name
body_parser = require 'body-parser'

make_id = (t,n) -> [t,n].join ':'

{show,list} = require './opensips'
{unquote_params} = require '../quote'
zappa_as_promised = require '../zappa-as-promised'

module.exports = (cfg) ->
  debug 'Using configuration', cfg

  cfg.host ?= (require 'os').hostname()

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
    doc ?= _id:aor, hostname:cfg.host

    doc._in = [
      "endpoint:#{aor}"
    ]
    [username,domain] = aor.split '@'
    if username? and domain?
      doc._in.push "domain:#{domain}"
    cfg.socket.emit 'location:response', doc

  # Reply to requests for all AORs.
  cfg.socket?.on 'locations', ->
    docs = {}
    cfg.usrloc.forEach (value,key) ->
      docs[key] = value
    cfg.socket.emit 'locations:response', docs

  # Ping
  cfg.socket?.on 'ping', (doc) ->
    cfg.socket.emit 'pong', host:cfg.host, in_reply_to:doc, name:pkg.name, version:pkg.version

  zappa_as_promised main, cfg

main = (cfg) ->

  ->
    @use morgan:'combined'

    # REST/JSON API
    queries =
      location: 0
      save_location: 0
      version: 0

    @get '/', ->
      @json {
        name
        version: pkg.version
        queries
      }

    # OpenSIPS db_http API (for locations only)

    @get '/location/': -> # usrloc_table
      queries.location++

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
      queries.save_location++

      doc = unquote_params(@body.k,@body.v,'location')
      # Note: this allows for easy retrieval, but only one location can be stored.
      # Use "callid" as an extra key parameter otherwise.
      doc._id = "#{doc.username}@#{doc.domain}"

      if @body.uk?
        update_doc = unquote_params(@body.uk,@body.uv,'location')
        doc[k] = v for k,v of update_doc

      doc.hostname ?= cfg.host
      doc.query_type = @body.query_type

      # Socket.IO notification
      notification =
        _in: [
          "domain:#{doc.domain}"
          "endpoint:#{doc._id}"
        ]
      for own k,v of doc
        notification[k] = v
      cfg.socket?.emit 'location:update', notification

      # Storage
      if @body.query_type is 'insert' or @body.query_type is 'update'

        @res.type 'text/plain'
        @send doc._id
        cfg.usrloc.set doc._id, doc
        return

      if @body.query_type is 'delete'

        @send ''
        cfg.usrloc.del doc._id
        return

      @send ""

    @get '/version/': ->
      queries.version++
      if @query.k is 'table_name' and @query.c is 'table_version'

        # Versions for OpenSIPS 1.11.0 FIXME
        versions =
          location: 1009

        return "int\n#{versions[@query.v]}\n"

      @send ""
