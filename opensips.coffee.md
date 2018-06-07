    module.exports = ->

Start the processes
===================

      SHARED_MEMORY = process.env.SHARED_MEMORY ? 64
      PACKAGE_MEMORY = process.env.PACKAGE_MEMORY ? 16

      s = child_process.spawn '/opt/opensips/sbin/opensips',
        [ '-f', '/opt/opensips/etc/opensips/opensips.cfg', '-m', SHARED_MEMORY, '-M', PACKAGE_MEMORY, '-F', '-E', '-w', '/tmp' ],
        stdio: ['ignore',process.stdout,process.stderr]
        env: TZ:'UTC'

      s.once 'close', (code,signal) ->
        debug.dev "Process closed with code #{code}, signal #{signal}"
        process.exit code

      s.once 'error', (error) ->
        debug.dev "Process exited with error #{error}"
        process.exit 1

      s.once 'exit', (code,signal) ->
        debug.dev "Process exited with code #{code}, signal #{signal}"
        process.exit code

      process.once 'exit', -> s.kill()

      s

    child_process = require 'child_process'
    debug = (require 'tangible') 'thinkable-ducks:freeswitch'
