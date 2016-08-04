Web Services for Munin
======================

    run = (cfg) ->
      cfg.munin ?= {}
      cfg.munin.host ?= process.env.MUNIN_HOST ? '127.0.0.1'
      cfg.munin.port ?= process.env.MUNIN_PORT ? 3949
      cfg.munin.io ?= false

      config = build_config cfg

      Zappa cfg.munin, ->

        @get '/autoconf', ->
          @send 'yes\n'
          return

        @get '/config', ->
          @send config
          return

        @get '/', ->
          text = ''
          ip = cfg.httpd_ip ? '127.0.0.1'
          port = cfg.httpd_port ? 8560
          request
          .get "http://#{ip}:#{port}/json/uptime"
          .accept 'json'
          .then ({body}) =>
            uptime = parseInt body['Up time']
            text += """
              multigraph #{name}_uptime
              #{name}_node_uptime.value #{uptime}

            """

            request
            .get "http://#{ip}:#{port}/json/get_statistics"
            .query params:'all'
            .accept 'json'
          .then ({body}) =>
            doc = body
            text += """
              multigraph #{name}_core
              #{name}_core_rcv_req.value #{doc['core:rcv_requests']}
              #{name}_core_rcv_repl.value #{doc['core:rcv_replies']}
              #{name}_core_fwd_req.value #{doc['core:fwd_requests']}
              #{name}_core_fwd_repl.value #{doc['core:fwd_replies']}
              #{name}_core_drop_req.value #{doc['core:drop_requests']}
              #{name}_core_drop_repl.value #{doc['core:drop_replies']}
              #{name}_core_err_req.value #{doc['core:err_requests']}
              #{name}_core_err_repl.value #{doc['core:err_replies']}

              multigraph #{name}_shmem
              #{name}_shmem_total.value #{doc['shmem:total_size']}
              #{name}_shmem_used.value #{doc['shmem:used_size']}

              multigraph #{name}_tm
              #{name}_tm_total.value #{doc['tm:UAS_transactions']}
              #{name}_tm_2xx.value #{doc['tm:2xx_transactions']}
              #{name}_tm_3xx.value #{doc['tm:3xx_transactions']}
              #{name}_tm_4xx.value #{doc['tm:4xx_transactions']}
              #{name}_tm_5xx.value #{doc['tm:5xx_transactions']}
              #{name}_tm_6xx.value #{doc['tm:6xx_transactions']}

              multigraph #{name}_dialog_active
              #{name}_dialog_active.value #{doc['dialog:active_dialogs']}

              multigraph #{name}_dialog
              #{name}_dialog_processed.value #{doc['dialog:processed_dialogs']}
              #{name}_dialog_failed.value #{doc['dialog:failed_dialogs']}

            """
            switch cfg.model
              when 'registrant'
                text += ''
              else
                text += """
                  multigraph #{name}_usrloc
                  #{name}_usrloc_total.value #{doc['usrloc:registered_users']}
                  #{name}_usrloc_location.value #{doc['usrloc:location_contacts']}

                  multigraph #{name}_registrar
                  #{name}_registrar_accepted.value #{doc['registrar:accepted_regs']}
                  #{name}_registrar_rejected.value #{doc['registrar:rejected_regs']}

                """

            memory = process.memoryUsage()
            text += """
              multigraph #{name}_node_uptime
              #{name}_node_uptime.value #{process.uptime()}

              multigraph #{name}_node_memory
              #{name}_node_memory_rss.value #{memory.rss}
              #{name}_node_memory_heap_total.value #{memory.heapTotal}
              #{name}_node_memory_heap_used.value #{memory.heapUsed}

            """

            @send text


Munin Configuration
===================

    name = 'opensips'

    build_config = (cfg) ->
      text = """
        multigraph #{name}_uptime
        graph_args --base 1000 -l 0
        graph_category voice
        graph_scale no
        graph_title OpenSIPS uptime
        graph_vlabel seconds
        #{name}_node_uptime.label uptime
        #{name}_node_uptime.draw AREA

        multigraph #{name}_core
        graph_args --base 1000 -l 0
        graph_category voice
        graph_title OpenSIPS core
        graph_vlabel requests / ${graph_period}
        #{name}_core_rcv_req.label received requests
        #{name}_core_rcv_req.type DERIVE
        #{name}_core_rcv_req.min 0
        #{name}_core_rcv_repl.label received replies
        #{name}_core_rcv_repl.type DERIVE
        #{name}_core_rcv_repl.min 0
        #{name}_core_fwd_req.label forwarded requests
        #{name}_core_fwd_req.type DERIVE
        #{name}_core_fwd_req.min 0
        #{name}_core_fwd_repl.label forwarded replies
        #{name}_core_fwd_repl.type DERIVE
        #{name}_core_fwd_repl.min 0
        #{name}_core_drop_req.label dropped requests
        #{name}_core_drop_req.type DERIVE
        #{name}_core_drop_req.min 0
        #{name}_core_drop_repl.label dropped replies
        #{name}_core_drop_repl.type DERIVE
        #{name}_core_drop_repl.min 0
        #{name}_core_err_req.label request errors
        #{name}_core_err_req.type DERIVE
        #{name}_core_err_req.min 0
        #{name}_core_err_repl.label reply errors
        #{name}_core_err_repl.type DERIVE
        #{name}_core_err_repl.min 0

        multigraph #{name}_shmem
        graph_args --base 1024 -l 0
        graph_category voice
        graph_title OpenSIPS memory pool
        graph_vlabel bytes
        #{name}_shmem_total.label total
        #{name}_shmem_used.label used

        multigraph #{name}_tm
        graph_args --base 1000 -l 0
        graph_category voice
        graph_title OpenSIPS transactions
        graph_vlabel transactions / ${graph_period}
        #{name}_tm_total.label total
        #{name}_tm_total.type DERIVE
        #{name}_tm_total.min 0
        #{name}_tm_2xx.label 2xx transactions
        #{name}_tm_2xx.type DERIVE
        #{name}_tm_2xx.min 0
        #{name}_tm_3xx.label 3xx transactions
        #{name}_tm_3xx.type DERIVE
        #{name}_tm_3xx.min 0
        #{name}_tm_4xx.label 4xx transactions
        #{name}_tm_4xx.type DERIVE
        #{name}_tm_4xx.min 0
        #{name}_tm_5xx.label 5xx transactions
        #{name}_tm_5xx.type DERIVE
        #{name}_tm_5xx.min 0
        #{name}_tm_6xx.label 6xx transactions
        #{name}_tm_6xx.type DERIVE
        #{name}_tm_6xx.min 0

        multigraph #{name}_dialog_active
        graph_args --base 1000 -l 0
        graph_category voice
        graph_title OpenSIPS SIP active dialogs
        graph_vlabel active dialogs
        #{name}_dialog_active.label active
        #{name}_dialog_active.min 0

        multigraph #{name}_dialog
        graph_args --base 1000 -l 0
        graph_category voice
        graph_title OpenSIPS SIP dialogs
        graph_vlabel dialogs / ${graph_period}
        #{name}_dialog_processed.label processed
        #{name}_dialog_processed.type DERIVE
        #{name}_dialog_processed.min 0
        #{name}_dialog_failed.label failed
        #{name}_dialog_failed.type DERIVE
        #{name}_dialog_failed.min 0

      """
      switch cfg.model
        when 'registrant'
          text += ''
        else
          text += """
            multigraph #{name}_usrloc
            graph_args --base 1000 -l 0
            graph_category voice
            graph_scale no
            graph_title OpenSIPS registered users
            graph_vlabel users
            #{name}_usrloc_total.label total
            #{name}_usrloc_location.label locations
            #{name}_usrloc_location.min 0

            multigraph #{name}_registrar
            graph_args --base 1000 -l 0
            graph_category voice
            graph_title OpenSIPS registrar
            graph_vlabel registrations / ${graph_period}
            #{name}_registrar_accepted.label accepted
            #{name}_registrar_accepted.type DERIVE
            #{name}_registrar_accepted.min 0
            #{name}_registrar_rejected.label rejected
            #{name}_registrar_rejected.type DERIVE
            #{name}_registrar_rejected.min 0

          """

      text += """
        multigraph #{name}_node_uptime
        graph_args --base 1000 -l 0
        graph_category voice
        graph_scale no
        graph_title OpenSIPS Node.js uptime
        graph_vlabel seconds
        #{name}_node_uptime.label uptime
        #{name}_node_uptime.draw AREA

        multigraph #{name}_node_memory
        graph_args --base 1024 -l 0
        graph_category voice
        graph_title OpenSIPS Node.js memory
        graph_vlabel bytes
        #{name}_node_memory_rss.label rss
        #{name}_node_memory_rss.min 0
        #{name}_node_memory_heap_total.label heap (total)
        #{name}_node_memory_heap_total.min 0
        #{name}_node_memory_heap_used.label heap (used)
        #{name}_node_memory_heap_used.min 0

      """

      text

Toolbox
=======

    Promise = require 'bluebird'
    Zappa = require 'zappajs'
    pkg = require '../package.json'
    debug = (require 'debug') "#{pkg.name}:munin"
    request = (require 'superagent-as-promised') require 'superagent'
    seconds = 1000
    minutes = 60*seconds

Start
=====

    module.exports = run
