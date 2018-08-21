    Express = require 'express'
    morgan = require 'morgan'
    {promisify} = require 'util'

    RedRingAxon = require 'red-rings-axon'
    {SUBSCRIBE} = require 'red-rings/operations'

    LRU = require 'lru-cache'

    {show,list} = require './opensips'
    {unquote_params} = require '../quote'

    pkg = require '../../package.json'
    name = "#{pkg.name}:client"
    {debug} = (require 'tangible') name

Export
======

    module.exports = (cfg) ->
      # debug 'Using configuration', cfg

      cfg.host ?= (require 'os').hostname()

Map AOR to a list of contact IDs

      cfg.usrloc = LRU
        # Store at most 6000 entries
        max: 6000
        # For at most 24 hours
        maxAge: 24 * 3600 * 1000

Contact records, indexed on contact IDs

      cfg.usrloc_data = LRU
        # Store at most 18000 entries
        max: 3*6000
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

      cfg.domains = LRU
        # Store at most 100 entries
        max: 100
        # For at most 1 minute
        maxAge: 60 * 1000

Retrieve domain data
--------------------

Using the database with a LRU for cache.

      cfg.get_domain = (domain) ->
        v = cfg.domains.get domain
        return v.doc if v?

        doc = await cfg.prov
          .get "number_domain:#{domain}"
          .catch ->
            null
        if doc?
          doc.domain ?= doc.number_domain
        cfg.domains.set domain, {doc}
        return doc

Iterate over all AORs / all contacts,
generating at least one document per known AOR.

      cfg.all_contacts = (handler) ->
        cfg.usrloc.forEach (cids,aor) ->
          cfg.for_contact_in_aor aor, handler

Iterate over all contacts for the AOR,
generating at least one document.

      cfg.for_contact_in_aor = (aor,handler) ->
        return unless aor? and typeof aor is 'string'
        [username,domain] = aor.split '@'
        extend = (doc) ->
          doc.aor ?= aor
          doc.username ?= username
          doc.domain ?= domain
          doc.hostname ?= cfg.host
          doc

        cids = cfg.get_cids_for_aor aor
        if cids.length > 0
          cids.forEach (cid) ->
            doc = cfg.get_doc_for_cid cid
            handler extend doc
        null

(Internal) returns an array containing all Contact IDs for an AOR.
Contact IDs are used internally by OpenSIPS to identify unique Contacts for an AOR.

      cfg.get_cids_for_aor = (aor) ->
        return unless aor?
        cids = cfg.usrloc.get aor
        cids ?= []

Add a given Contact ID to the AOR.

      cfg.add_cid_to_aor = (aor,cid) ->
        return unless aor? and cid?
        cids = cfg.get_cids_for_aor aor
        if cid not in cids
          cids.push cid
        cfg.usrloc.set aor, cids

Retrieve the document for a given Contact ID.

      cfg.get_doc_for_cid = (cid) ->
        doc = cfg.usrloc_data.get cid
        doc ?= _id:cid, _missing:true, hostname: cfg.host, contact_id:cid
        doc

Save the document for a given Contact.

      cfg.save_contact = (doc) ->
        cfg.usrloc_data.set doc._id, doc

Reply to requests for a single AOR.
----------------------------------

      cfg.rr = new RedRingAxon cfg.axon ? {}

      cfg.rr
      .receive 'endpoint:*'
      .filter ({op}) -> op is SUBSCRIBE
      .observe ({key}) ->
        try
          return unless $ = key.match /^endpoint:(\S+)$/
          aor = $[1]
          cfg.for_contact_in_aor aor, (doc) ->
            cfg.rr.notify key, doc._id, doc
        catch error
          debug.dev 'aor notify', error
        return

      app = Express()
      main app, cfg
      new Promise (resolve,reject) ->
        server = app.listen cfg.web.port, cfg.web.host, ->
          debug 'Started'
          resolve server
        server.once 'error', reject
        return

ZappaJS server
==============

    main = (app,cfg) ->

      app.use morgan 'combined'

REST/JSON API

      queries =
        domain: 0
        location: 0
        save_location: 0
        presentity: 0
        save_presentity: 0
        active_watchers: 0
        save_active_watchers: 0
        watchers: 0
        save_watchers: 0
        pua: 0
        save_pua: 0
        version: 0

      app.get '/', (req,res) ->
          res.json {
            name
            version: pkg.version
            queries
            cache:
              usrloc:
                length: cfg.usrloc.length
                count:  cfg.usrloc.itemCount
              usrloc_data:
                length: cfg.usrloc_data.length
                count:  cfg.usrloc_data.itemCount
              presentities:
                length: cfg.presentities.length
                count:  cfg.presentities.itemCount
              active_watchers:
                length: cfg.active_watchers.length
                count:  cfg.active_watchers.itemCount
              watchers:
                length: cfg.watchers.length
                count:  cfg.watchers.itemCount
              domains:
                length: cfg.domains.length
                count:  cfg.domains.itemCount
          }

OpenSIPS db_http API
====================

Domain
------

      app.get '/domain/', (req,res) ->
          queries.domain++
          if req.query.k is 'domain' and (not req.query.op? or req.query.op is '=')
            doc = await cfg.get_domain req.query.v
            res.type 'text/plain'
            res.send show doc, req, 'domain'
            return

          debug "domain: not handled: #{req.query.k} #{req.query.op} #{req.query.v}"
          res.send ''

Location
--------

      app.get '/location/', (req,res) -> # usrloc_table
          queries.location++

          if req.query.k is 'username' and req.query.op is '='
            aor = req.query.v

          if req.query.k is 'username,domain' and req.query.op is '=,='
            [username,domain] = req.query.v.split ','
            aor = "#{username}@#{domain}"

          if aor?
            rows = []
            cfg.for_contact_in_aor aor, (doc) ->
              rows.push {doc} unless doc._deleted or doc._missing

            res.type 'text/plain'
            res.send list rows, req, 'location'
            return

          if not req.query.k? or (req.query.k is 'username' and not req.query.op?)
            rows = []
            cfg.all_contacts (doc) ->
              rows.push {doc} unless doc._deleted or doc._missing

            res.type 'text/plain'
            res.send list rows, req, 'location'
            return

          debug "location: not handled: #{req.query.k} #{req.query.op} #{req.query.v}"
          res.send ''

      app.post '/location', (Express.urlencoded extended:false), (req,res) ->
          queries.save_location++

          doc = unquote_params(req.body.k,req.body.v,'location')

          if req.body.uk?
            update_doc = unquote_params(req.body.uk,req.body.uv,'location')
            doc[k] = v for own k,v of update_doc

Keep any data previously stored with the same contact-id.

          old_doc = cfg.get_doc_for_cid doc.contact_id
          unless old_doc._missing
            for own k,v of old_doc
              doc[k] ?= v

OpenSIPS 2.2 only gives us the `contact_id` on updates; we get username and domain only on inserts.

          if doc.username? and doc.domain?
            doc.aor ?= "#{doc.username}@#{doc.domain}"

          if req.body.query_type is 'delete'
            doc._deleted = true
          else
            doc._deleted = null

          doc._id = doc.contact_id

          doc.hostname = cfg.host
          doc.query_type = req.body.query_type
          doc.query_time = new Date().toJSON()

Data is now finalized, store it and notify.

          cfg.save_contact doc

          if doc.aor?
            cfg.add_cid_to_aor doc.aor, doc.contact_id

            key = "endpoint:#{doc.aor}"
            cfg.for_contact_in_aor doc.aor, (this_doc) ->
              cfg.rr.notify key, this_doc._id, this_doc

          else
            debug 'Missing aor'

          debug 'location', doc

Response

          if req.body.query_type is 'insert' or req.body.query_type is 'update'

            res.type 'text/plain'
            res.send doc._id
            return

          if req.body.query_type is 'delete'
            res.send ''
            return

          debug "location: not handled: #{req.query.k} #{req.query.op} #{req.query.v}"
          res.send ''

Presentity
----------

Status for a given presentity.

      app.get '/presentity/', (req,res) ->
          queries.presentity++

At startup
> GET with c='username,domain,event,expires,etag'

          if not req.query.k?
            rows = []
            cfg.presentities.forEach (value,key) ->
              rows.push {key,value}

            res.type 'text/plain'
            res.send list rows, req, 'presentity'
            return

Upon PUBLISH
in modules/presence/publish.c, 'cleaning expired presentity information'
> GET with { k: 'expires', op: '<', v: '1464611367', c: 'username,domain,etag,event' }

          if req.query.k is 'expires' and req.query.op is '<'
            v = req.query.v
            debug 'get presentities expiring before', v
            rows = []
            cfg.presentities.forEach (value,key) ->
              if value.expires < v
                rows.push {key,value}

            res.type 'text/plain'
            res.send list rows, req, 'presentity'
            return

> GET { k: 'domain,username,event', v: 'test.phone.kwaoo.net,0972222713,message-summary', c: 'body,extra_hdrs,expires,etag' }

          if req.query.k is 'domain,username,event'
            _upid = req.query.v
            debug 'get presentities for', _upid
            o = cfg.presentities.get _upid
            rows = []
            for own key,value of o
              rows.push {key,value}
            res.type 'text/plain'
            res.send list rows, req, 'presentity'
            return

          debug 'presentity: not handled', req.query
          res.send ''

      app.post '/presentity', (Express.urlencoded extended:false), (req,res) ->
          queries.save_presentity++

          doc = unquote_params(req.body.k,req.body.v,'presentity')
          doc._id = "#{doc.username}@#{doc.domain}/#{doc.event}/#{doc.etag}"
          doc._upid = [doc.domain,doc.username,doc.event].join ','

          doc.hostname ?= cfg.host
          doc.query_type = req.body.query_type
          doc.query_time = new Date().toJSON()

          # Storage
          if req.body.query_type is 'insert'
            maxAge = doc.expires*1000 - Date.now()
            debug 'save presentity', doc, maxAge

FIXME should prune old presentities in the `o` while we are at it.

            o = cfg.presentities.get doc._upid
            o ?= {}
            o[doc.etag] = doc
            cfg.presentities.set doc._upid, o, maxAge

            res.type 'text/plain'
            res.send doc._id
            return

          if req.body.query_type is 'update' and req.query.k is 'domain,username,event,etag'
            update_doc = unquote_params(req.body.uk,req.body.uv,'presentity')

            debug 'update presentity', doc, update_doc
            o = cfg.presentities.get doc._upid
            o ?= {}

            new_doc = {}
            new_doc[k] = v for own k,v of doc
            new_doc[k] = v for own k,v of update_doc
            maxAge = new_doc.expires*1000 - Date.now()

            if doc.etag isnt new_doc.etag
              delete o[doc.etag]
            o[new_doc.etag] = new_doc

            cfg.presentities.set doc._upid, o, maxAge
            res.type 'text/plain'
            res.send doc._id
            return

          if req.body.k is 'expires' and req.body.op is '<' and req.body.query_type is 'delete'
            debug 'delete presentity older than', req.body.v

No action is needed, we're using the LRU maxAge (see above).

            res.type 'text/plain'
            res.send ''
            return

          if req.body.query_type is 'delete' and req.query.k is 'domain,username,event,etag'
            debug 'delete presentity', doc._upid
            o = cfg.presentities.get doc._upid
            o ?= {}
            delete o[doc.etag]
            cfg.presentities.set doc._upid, o, maxAge
            res.type 'text/plain'
            res.send ''
            return

          debug 'presentity: not handled', req.body
          res.send ''

Active Watchers
---------------

      app.get '/active_watchers/', (req,res) ->
          queries.active_watchers++

> GET with c='presentity_uri,expires,event,event_id,to_user,to_domain,watcher_username,watcher_domain,callid,to_tag,from_tag,local_cseq,remote_cseq,record_route,socket_info,contact,local_contact,version,status,reason'

          if not req.query.k?
            debug 'return all active watchers'
            rows = []
            cfg.active_watchers.forEach (value,key) ->
              rows.push {key,value}

            res.type 'text/plain'
            res.send list rows, req, 'active_watchers'
            return

          debug 'active_watchers: not handled', req.query
          res.send ''

      app.post '/active_watchers', (Express.urlencoded extended:false), (req,res) ->
          queries.save_active_watchers++

> POST (delete) all ... with query_type: 'delete'

          if not req.body.k? and req.body.query_type is 'delete'
            debug 'delete all active watchers'
            cfg.active_watchers.reset()
            res.type 'text/plain'
            res.send ''
            return

          if req.body.k is 'expires' and req.body.op is '<' and req.body.query_type is 'delete'
            debug 'delete active-watchers older than', req.body.v

No action is needed, we're using the LRU maxAge (see below).

            res.type 'text/plain'
            res.send ''
            return

> POST with { k: 'domain,username,event,etag,expires,sender,body,received_time', v: 'test.centrex.phone.kwaoo.net,10,message-summary,a.1464611276.25.1.0,1464615873,,Message-Waiting: yes,1464612273', query_type: 'insert' }
> POST with { k: 'presentity_uri,callid,to_tag,from_tag', v: 'sip:0972222713@test.phone.kwaoo.net,dea356ce-265e2f4b@192.168.1.106,5f158970a8f4a54eb5ed152ac4e28c95.3e20,4ea68f2f193a377', uk: 'expires,status,reason,remote_cseq,local_cseq,contact,version', uv: '1464697125,1,,54092,3,sip:0972222713@80.67.176.127:5063,3', query_type: 'update' }

          doc = unquote_params(req.body.k,req.body.v,'active_watchers')
          doc._id = [doc.presentity_uri,doc.callid,doc.to_tag,doc.from_tag].join ','

          doc.hostname ?= cfg.host
          doc.query_type = req.body.query_type
          doc.query_time = new Date().toJSON()

          if req.body.uk?
            update_doc = unquote_params(req.body.uk,req.body.uv,'active_watchers')
            doc[k] = v for own k,v of update_doc

          if req.body.query_type is 'insert' or req.body.query_type is 'update'
            maxAge = doc.expires*1000 - Date.now()
            debug 'save active-watchers', doc, maxAge

            cfg.active_watchers.set doc._id, doc, maxAge
            res.type 'text/plain'
            res.send doc._id
            return

          debug 'active_watchers: not handled', req.body
          res.send ''

Watchers
--------

> POST (delete all)

      app.get '/watchers/', (req,res) ->
          queries.watchers++

          debug 'watchers: not handled', req.query
          res.send ''

      app.post '/watchers', (Express.urlencoded extended:false), (req,res) ->
          queries.save_watchers++

          if not req.body.k? and req.body.query_type is 'delete'
            debug 'delete all watchers'
            cfg.watchers.reset()
            res.type 'text/plain'
            res.send ''
            return

          debug 'watchers: not handled', req.body
          res.send ''

Presence client / User Agent
----------------------------

      app.get '/pua/', (req,res) ->
          queries.pua++

          debug 'pua: not handled', req.query
          res.send ''

      app.post '/pua', (Express.urlencoded extended:false), (req,res) ->
          queries.save_pua++

          debug 'pua: not handled', req.body
          res.send ''

Versions
--------

      app.get '/version/', (req,res) ->
          queries.version++
          if req.query.k is 'table_name' and req.query.c is 'table_version'

            debug 'version for', req.query.v

Versions for OpenSIPS 2.2

            versions =
              location: 1011
              presentity: 5
              active_watchers: 11
              watchers: 4
              pua: 8

            res.send "int\n#{versions[req.query.v]}\n"
            return

          res.send ''
          return
