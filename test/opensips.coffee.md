    child_process = require 'child_process'
    {promisifyAll} = require 'bluebird'
    fs = promisifyAll require 'fs'
    request = require 'superagent'
    debug = (require 'tangible') 'ccnq4-opensips:test:opensips'
    sleep = (timeout) -> new Promise (resolve) -> setTimeout resolve, timeout

    opensips = (port,cfg) ->
      debug 'Going to start opensips on port', port
      cfg_file = "/tmp/config-#{port}"
      await fs.writeFileAsync cfg_file, cfg
      s = child_process.spawn '/opt/opensips/sbin/opensips',
          [
            '-f', cfg_file
            '-m', '64'
            '-M', '16'
            '-F' # no daemon
            '-E' # log to stderr
            '-w', '/tmp'
          ],
          stdio: if process.env.DEBUG then ['ignore',process.stdout,process.stderr] else ['ignore','ignore','ignore']
          end: TZ:'UTC'
      kill = ->
        await sleep 500
        s.kill()
        await sleep 500

    module.exports = opensips
