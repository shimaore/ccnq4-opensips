    module.exports = (func,cfg) ->

      new Promise (resolve,reject) ->
        try
          {server} = z = Zappa.app (func cfg), io:no
          server.on 'listening', ->
            resolve z
          debug 'listen', cfg.web
          server.listen cfg.web.port, cfg.web.host
        catch error
          reject error

    Promise = require 'bluebird'
    Zappa = require 'zappajs'
    pkg = require '../package'
    debug = (require 'debug') "#{pkg.name}:zappa-as-promised"
