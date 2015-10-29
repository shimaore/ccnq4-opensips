zappa = require 'zappajs'
io = require 'socket.io-client'
PouchDB = require 'pouchdb'
pkg = require '../../package.json'
name = "#{pkg.name}:registrant"
debug = (require 'debug') name
seem = require 'seem'

{list} = require './opensips'
couchapp = require './couchapp'
zappa_as_promised = require '../zappa-as-promised'
hostname = (require 'os').hostname()

request = (require 'superagent-as-promised') require 'superagent'
url = require 'url'

module.exports = seem (cfg) ->

  yield cfg.push couchapp

  cfg.socket = io cfg.notify if cfg.notify?

  # Subscribe to the `locations` bus.
  cfg.socket?.on 'welcome', ->
    cfg.socket.emit 'configure', locations:true

  # Reply to requests for all AORs.
  cfg.socket?.on 'registrants', seem ->
    debug 'socket: registrants'
    cfg.socket.emit 'registrants:response',
      yield request
        .get url.format
          protocol: 'http'
          hostname: cfg.opensips.httpd_ip
          port: cfg.opensips.httpd_port
          pathname: '/json/reg_list'
        .type 'json'
    debug 'socket: registrants done'

  # Ping
  cfg.socket?.on 'ping', (doc) ->
    cfg.socket.emit 'pong', host:hostname, in_reply_to:doc, name:pkg.name, version:pkg.version

  zappa_as_promised main, cfg

main = (cfg) ->

  debug 'Using configuration', cfg

  ->
    @use morgan:'combined'

    # REST/JSON API
    queries =
      version: 0
      registrant: 0

    @get '/', ->
      @json {
        name
        version: pkg.version
        queries
      }

    @get '/registrant/': ->
      queries.registrant++
      if not @query.k?
        cfg.prov.query "#{couchapp.id}/registrant_by_host",
          startkey: [cfg.opensips.host]
          endkey: [cfg.opensips.host,{}]
        .then ({rows}) =>
          @send list rows, @req, 'registrant'
        .catch (error) =>
          debug "query: #{error}"
          @send ""
        return

      @send ""

    @get '/version/': ->
      queries.version++
      if @query.k is 'table_name' and @query.c is 'table_version'

        versions =
          registrant: 1

        return "int\n#{versions[@query.v]}\n"

      @send ""
