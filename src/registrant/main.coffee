#!/usr/bin/env coffee
###
(c) 2010 Stephane Alnet
Released under the AGPL3 license
###

util = require 'util'
qs = require 'querystring'
request = require 'superagent-as-promised'

make_id = (t,n) -> [t,n].join ':'

require('ccnq3').config (config)->

  config.opensips_proxy ?= {}
  config.opensips_proxy.port ?= 34340
  config.opensips_proxy.hostname ?= "127.0.0.1"
  config.opensips_proxy.usrloc_uri ?= "http://127.0.0.1:5984/location"

  zappa = require 'zappajs'
  zappa config.opensips_proxy.port, config.opensips_proxy.hostname, {config}, ->

    @use 'bodyParser'

    {column_types} = require 'quote'

    _request = (that,loc) ->
      r = request loc, (e,r,b) ->
        if e?
          util.log loc + 'failed with error ' + util.inspect e
      r.pipe(that.response)

    _pipe = (that,base,t,id) ->
      loc = "#{base}/_design/opensips/_show/format/#{qs.escape id}?t=#{t}&c=#{qs.escape that.query.c}"
      _request that, loc

    pipe_req = (that,t,id) ->
      _pipe that, config.provisioning.local_couchdb_uri, t, id

    pipe_loc_req = (that,t,id) ->
      _pipe that, config.opensips_proxy.usrloc_uri, t, id

    _list = (that,base,t,view) ->
      loc = "#{base}/_design/opensips/_list/format/#{view}?t=#{t}&c=#{qs.escape that.query.c}"
      _request that, loc

    pipe_list = (that,t,view) ->
      _list that, config.provisioning.local_couchdb_uri, t, view

    _list_key = (that,base,t,view,key,format) ->
      key = "\"#{key}\""
      loc = "#{base}/_design/opensips/_list/#{format}/#{view}?t=#{t}&c=#{qs.escape that.query.c}&key=#{qs.escape key}"
      _request that, loc

    pipe_list_key = (that,t,view,key,format='format') ->
      _list_key that, config.provisioning.local_couchdb_uri, t, view, key, format

    _list_keys = (that,base,t,view,key,format) ->
      startkey = """["#{key}"]"""
      endkey   = """["#{key}",{}]"""
      loc = "#{base}/_design/opensips/_list/#{format}/#{view}?t=#{t}&c=#{qs.escape that.query.c}&startkey=#{qs.escape startkey}&endkey=#{qs.escape endkey}"
      _request that, loc

    pipe_list_keys = (that,t,view,key,format='format') ->
      _list_keys that, config.provisioning.local_couchdb_uri, t, view, key, format


    # Action!
    @get '/subscriber/': -> # auth_table
      if @query.k is 'username,domain'
        # Parse @v -- what is the actual format?
        [username,domain] = @query.v.split ","
        pipe_req @, 'subscriber', make_id('endpoint',"#{username}@#{domain}")
        return

      util.error "subscriber: not handled: #{@query.k}"
      @send ""

    pipe_loc_list = (that,t,view) ->
      _list that, config.opensips_proxy.usrloc_uri, t, view

    @get '/location/': -> # usrloc_table

      if @query.k is 'username'
        pipe_loc_req @, 'usrloc', @query.v
        return

      if @query.k is 'username,domain'
        [username,domain] = @query.v.split ','
        pipe_loc_req @, 'usrloc', "#{username}@#{domain}"
        return

      if not @query.k?
        pipe_loc_list @, 'usrloc', 'location/all' # Can't use _all_docs
        return

      util.error "location: not handled: #{@query.k}"
      @send ""

    loc_db = pico config.opensips_proxy.usrloc_uri

    @post '/location': ->

      doc = unquote_params(@body.k,@body.v,'location')
      # Note: this allows for easy retrieval, but only one location can be stored.
      # Use "callid" as an extra key parameter otherwise.
      doc._id = "#{doc.username}@#{doc.domain}"

      if @body.uk?
        update_doc = unquote_params(@body.uk,@body.uv,'location')
        doc[k] = v for k,v of update_doc

      if @body.query_type is 'insert' or @body.query_type is 'update'

        loc_db.rev doc._id, (e,r,h) =>
          doc._rev = h.rev if h?.rev?
          loc_db.put doc, (e,r,p) =>
            if e then util.error "location: error updating #{doc._id}"
        @send doc._id
        return

      if @body.query_type is 'delete'

        loc_db.rev doc._id, (e,r,h) =>
          if not h?.rev? then return @send ""
          doc._rev = h.rev
          loc_db.remove doc, (e) =>
            if e then util.error "location: error removing #{doc._id}"
        @send ""
        return

      util.error "location: not handled: #{util.inspect @req}"
      @send ""

    @get '/registrant/': ->
      if not @query.k?
        pipe_list_keys @, 'registrant', 'registrant_by_host', config.host, 'registrant'
        return

      util.error "registrant: not handled: #{@query.k}"
      @send ""

    @get '/version/': ->
      if @query.k is 'table_name' and @query.c is 'table_version'

        # Versions for OpenSIPS 1.8.1
        versions =
          location: 1009
          subscriber: 7
          dr_gateways: 6
          dr_rules: 3
          registrant: 1

        return "int\n#{versions[@query.v]}\n"

      util.error "version not handled: #{util.inspect @req}"
      @send ""
