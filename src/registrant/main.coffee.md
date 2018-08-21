    Express = require 'express'
    morgan = require 'morgan'
    RedRingAxon = require 'red-rings-axon'
    {SUBSCRIBE} = require 'red-rings/operations'
    PouchDB = require 'ccnq4-pouchdb'

    hostname = (require 'os').hostname()
    request = require 'superagent'
    url = require 'url'
    {list} = require './opensips'
    CouchApp = require 'ccnq4-registrant-view'

    pkg = require '../../package.json'
    name = "#{pkg.name}:registrant"
    {debug,foot} = (require 'tangible') name

Export
======

    module.exports = (cfg) ->
      # debug 'Using configuration', cfg

      cfg.host ?= (require 'os').hostname()

      cfg.couchapp = CouchApp.couchapp cfg

      await cfg.push cfg.couchapp

      cfg.rr = new RedRingAxon cfg.axon ? {}

      cfg.rr
      .receive 'registrants'
      .filter ({op}) -> op is SUBSCRIBE
      .observe foot (msg) ->
        {body} = await request
          .get url.format
            protocol: 'http'
            hostname: cfg.opensips.httpd_ip
            port: cfg.opensips.httpd_port
            pathname: '/json/reg_list'
          .accept 'json'
        cfg.rr.notify msg.key, "host:#{cfg.host}", body
        return
      .catch console.error

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
        version: 0
        registrant: 0

      app.get '/', (req,res) ->
          res.json {
            name
            version: pkg.version
            queries
          }

OpenSIPS db_http API
====================

Registrant
----------

      app.get '/registrant/', (req,res) ->
          queries.registrant++
          if not req.query.k?
            cfg.prov.query "#{CouchApp.app}/by_host",
              startkey: [ cfg.opensips.host ]
              endkey: [ cfg.opensips.host, {} ]
            .then ({rows}) =>
              res.send list rows, req, 'registrant'
            .catch (error) =>
              debug "query: #{error}"
              res.status(500).end()
            return

          res.send ''
          return

Versions
--------

        app.get '/version/', (req,res) ->
          queries.version++
          if req.query.k is 'table_name' and req.query.c is 'table_version'

            debug 'version for', req.query.v

Versions for OpenSIPS 2.2

            versions =
              registrant: 1

            res.send "int\n#{versions[req.query.v]}\n"
            return

          res.send ''
          return
