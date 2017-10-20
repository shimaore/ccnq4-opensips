    seem = require 'seem'
    zappa = require 'zappajs'
    io = require 'socket.io-client'
    PouchDB = require 'ccnq4-pouchdb'

    hostname = (require 'os').hostname()
    request = require 'superagent'
    url = require 'url'
    {list} = require './opensips'
    CouchApp = require './couchapp'
    zappa_as_promised = require '../zappa-as-promised'

    pkg = require '../../package.json'
    name = "#{pkg.name}:registrant"
    debug = (require 'tangible') name
    opensips_debug = (require 'tangible') 'ccnq4-opensips:opensips'
    body_parser = require 'body-parser'


Export
======

    module.exports = seem (cfg) ->

      cfg.couchapp = CouchApp cfg

      yield cfg.push cfg.couchapp

      cfg.socket = io cfg.notify if cfg.notify?

Subscribe to the `locations` bus.

      cfg.socket?.on 'welcome', ->
        cfg.socket.emit 'configure', locations:true

Reply to requests for all AORs.
------------------------------

      cfg.socket?.on 'registrants', seem ->
        debug 'socket: registrants'
        {body} = yield request
          .get url.format
            protocol: 'http'
            hostname: cfg.opensips.httpd_ip
            port: cfg.opensips.httpd_port
            pathname: '/json/reg_list'
          .accept 'json'
        cfg.socket.emit 'registrants:response', body
        debug 'socket: registrants done'

      zappa_as_promised main, cfg

ZappaJS server
==============

    main = (cfg) ->

      ->
        @use morgan:'combined'

REST/JSON API

        queries =
          version: 0
          registrant: 0

        @get '/', ->
          @json {
            name
            version: pkg.version
            queries
          }

OpenSIPS db_http API
====================

Registrant
----------

        @get '/registrant/': ->
          queries.registrant++
          if not @query.k?
            cfg.prov.query "#{cfg.couchapp.id}/registrant_by_host",
              startkey: [ cfg.opensips.host ]
              endkey: [ cfg.opensips.host, {} ]
            .then ({rows}) =>
              @send list rows, @req, 'registrant'
            .catch (error) =>
              debug "query: #{error}"
              @res.status(500).end()
            return

          @send ""

Versions
--------

        @get '/version/': ->
          queries.version++
          if @query.k is 'table_name' and @query.c is 'table_version'

            debug 'version for', @query.v

Versions for OpenSIPS 2.2

            versions =
              registrant: 1

            return "int\n#{versions[@query.v]}\n"

          @send ''
