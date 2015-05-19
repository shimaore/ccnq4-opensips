    module.exports = (func,cfg) ->

      new Promise (resolve,reject) ->
        try
          {server} = z = Zappa.app (func cfg), io:no
          server.on 'listening', ->
            resolve z
          server.listen cfg.port, cfg.host
        catch error
          reject error

    Promise = require 'bluebird'
    Zappa = require 'zappajs'
