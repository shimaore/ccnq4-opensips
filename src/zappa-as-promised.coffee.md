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

    Zappa = require 'zappajs'
    pkg = require '../package'
    debug = (require 'tangible') "#{pkg.name}:zappa-as-promised"
