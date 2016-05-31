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

      cfg.presentities = LRU
        # Store at most 6000 entries
        max: 6000
        # For at most 24 hour
        maxAge: 24 * 3600 * 1000

      cfg.active_watchers = LRU
        # Store at most 6000 entries
        max: 6000
        # For at most 24 hour
        maxAge: 24 * 3600 * 1000

      cfg.watchers = LRU
        # Store at most 6000 entries
        max: 6000
        # For at most 24 hour
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

ZappaJS server
==============

    main = (cfg) ->

      ->
        @use morgan:'combined'

        # REST/JSON API
        queries =
          location: 0
          save_location: 0
          presentity: 0
          save_presentity: 0
          active_watchers: 0
          save_active_watchers: 0
          watchers: 0
          save_watchers: 0
          version: 0

        @get '/', ->
          @json {
            name
            version: pkg.version
            queries
          }

OpenSIPS db_http API
====================

Location
--------

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

          debug "location: not handled: #{@query.k} #{@query.op} #{@query.v}"
          @send ''

        @post '/location', (body_parser.urlencoded extended:false), ->
          queries.save_location++

          doc = unquote_params(@body.k,@body.v,'location')

Note: this allows for easy retrieval, but only one location can be stored.
The entire key should also have `callid` and `contact`.

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

          @send ''

Presentity
----------

Status for a given presentity.

        @get '/presentity/': ->
          queries.presentity++

At startup
> GET with c='username,domain,event,expires,etag'

          if not @query.k?
            rows = []
            cfg.presentities.forEach (value,key) ->
              rows.push {key,value}

            @res.type 'text/plain'
            @send list rows, @req, 'presentity'
            return

Upon PUBLISH
in modules/presence/publish.c, 'cleaning expired presentity information'
> GET with { k: 'expires', op: '<', v: '1464611367', c: 'username,domain,etag,event' }

          if @query.k is 'expires' and @query.op is '<'
            v = @query.v
            debug 'get presentities expiring before', v
            rows = []
            cfg.presentities.forEach (value,key) ->
              if value.expires < v
                rows.push {key,value}

            @res.type 'text/plain'
            @send list rows, @req, 'presentity'
            return

> GET { k: 'domain,username,event', v: 'test.phone.kwaoo.net,0972222713,message-summary', c: 'body,extra_hdrs,expires,etag' }

          if @query.k is 'domain,username,event'
            debug 'get presentities for', @query.k
            o = cfg.presentities.get @query.k
            rows = []
            for key,value of o
              rows.push {key,value}
            @res.type 'text/plain'
            @send list rows, @req, 'presentity'
            return

          debug 'presentity: not handled', @query
          @send ''

        @post '/presentity', (body_parser.urlencoded extended:false), ->
          queries.save_presentity++

          doc = unquote_params(@body.k,@body.v,'presentity')
          doc._id = "#{doc.username}@#{doc.domain}/#{doc.event}/#{doc.etag}"
          doc._upid = [doc.domain,doc.username,doc.event].join ','

          doc.hostname ?= cfg.host
          doc.query_type = @body.query_type

          # Storage
          if @body.query_type is 'insert'
            maxAge = doc.expires*1000 - Date.now()
            debug 'save presentity', doc, maxAge

FIXME should prune old presentities in the `o` while we are at it.

            o = cfg.presentities.get doc._upid
            o ?= {}
            o[doc.etag] = doc
            cfg.presentities.set doc._upid, doc, maxAge

            @res.type 'text/plain'
            @send doc._id
            return

          if @body.k is 'expires' and @body.op is '<' and @body.query_type is 'delete'
            debug 'delete presentity older than', @body.v

No action is needed, we're using the LRU maxAge (see above).

            @res.type 'text/plain'
            @send ''
            return

          debug 'presentity: not handled', @body
          @send ''

Active Watchers
---------------

        @get '/active_watchers/': ->
          queries.active_watchers++

> GET with c='presentity_uri,expires,event,event_id,to_user,to_domain,watcher_username,watcher_domain,callid,to_tag,from_tag,local_cseq,remote_cseq,record_route,socket_info,contact,local_contact,version,status,reason'

          if not @query.k?
            debug 'return all active watchers'
            rows = []
            cfg.presentities.forEach (value,key) ->
              rows.push {key,value}

            @res.type 'text/plain'
            @send list rows, @req, 'active_watchers'
            return

          debug 'active_watchers: not handled', @query
          @send ''

        @post '/active_watchers', (body_parser.urlencoded extended:false), ->
          queries.save_active_watchers++

> POST (delete) all ... with query_type: 'delete'

          if not @body.k? and @body.query_type is 'delete'
            debug 'delete all active watchers'
            cfg.active_watchers.reset()
            @res.type 'text/plain'
            @send ''
            return

          if @body.k is 'expires' and @body.op is '<' and @body.query_type is 'delete'
            debug 'delete active-watchers older than', @body.v

No action is needed, we're using the LRU maxAge (see below).

            @res.type 'text/plain'
            @send ''
            return

> POST with { k: 'domain,username,event,etag,expires,sender,body,received_time', v: 'test.centrex.phone.kwaoo.net,10,message-summary,a.1464611276.25.1.0,1464615873,,Message-Waiting: yes,1464612273', query_type: 'insert' }
> POST with { k: 'presentity_uri,callid,to_tag,from_tag', v: 'sip:0972222713@test.phone.kwaoo.net,dea356ce-265e2f4b@192.168.1.106,5f158970a8f4a54eb5ed152ac4e28c95.3e20,4ea68f2f193a377', uk: 'expires,status,reason,remote_cseq,local_cseq,contact,version', uv: '1464697125,1,,54092,3,sip:0972222713@80.67.176.127:5063,3', query_type: 'update' }

          doc = unquote_params(@body.k,@body.v,'active_watchers')
          doc._id = [doc.presentity_uri,doc.callid,doc.to_tag,doc.from_tag].join ','

          doc.hostname ?= cfg.host
          doc.query_type = @body.query_type

          if @body.uk?
            update_doc = unquote_params(@body.uk,@body.uv,'active_watchers')
            doc[k] = v for k,v of update_doc

          if @body.query_type is 'insert' or @body.query_type is 'update'
            maxAge = doc.expires*1000 - Date.now()
            debug 'save active-watchers', doc, maxAge

            cfg.active_watchers.set doc._id, doc, maxAge
            @res.type 'text/plain'
            @send doc._id
            return

          debug 'active_watchers: not handled', @body
          @send ''

Watchers
--------

> POST (delete all)

        @get '/watchers/': ->
          queries.watchers++

          debug 'watchers: not handled', @query
          @send ''

        @post '/watchers', (body_parser.urlencoded extended:false), ->
          queries.save_watchers++

          if not @body.k? and @body.query_type is 'delete'
            debug 'delete all watchers'
            cfg.watchers.reset()
            @res.type 'text/plain'
            @send ''
            return

          debug 'watchers: not handled', @body
          @send ''

Versions
--------

        @get '/version/': ->
          queries.version++
          if @query.k is 'table_name' and @query.c is 'table_version'

            debug 'version for', @query.v

            # Versions for OpenSIPS 2.1
            versions =
              location: 1009
              presentity: 5
              active_watchers: 10
              watchers: 4

            return "int\n#{versions[@query.v]}\n"

          @send ''
