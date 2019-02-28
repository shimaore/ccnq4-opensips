    # db_dbase.c lists: int, double, string, str, blob, date; str and blob are equivalent for this interface.
    column_types =
      version:
        table_name: 'string'
        table_version: 'int'
      dr_gateways:
        id: 'int'
        gwid: 'string'
        type: 'int'
        address: 'string'
        strip: 'int'
        pri_prefix: 'string'
        attrs: 'string'
        probe_mode: 'int'
        socket: 'string'
        state: 'int'
      dr_rules:
        ruleid: 'int'
        # keys
        groupid: 'string'
        prefix: 'string'
        timerec: 'string'
        priority: 'int'
        # others
        routeid: 'string'
        gwlist: 'string'
        attrs: 'string'
      dr_carriers:
        id: 'int'
        carrierid: 'string'
        gwlist: 'string'
        flags: 'int'
        attrs: 'string'
        state: 'int'
      dr_groups:
        username:'string'
        domain:'string'
        groupid:'int'
      domain:
        domain: 'string'
        attrs: 'string'
      subscriber:
        username: 'string'
        domain: 'string'
        password: 'string'
        ha1: 'string'
        ha1b: 'string'
        rpid: 'string'
      avpops:
        uuid: 'string'
        username: 'string'
        domain: 'string'
        attribute: 'string'
        type: 'int'
        value: 'string'
      location:
        contact_id:'string'
        # keys
        username:'string'
        contact:'string'
        callid:'string'
        domain:'string'
        # non-keys
        expires:'date'
        q:'double'
        cseq:'int'
        flags:'int'
        cflags:'string'
        user_agent:'string'
        received:'string'
        path:'string'
        socket:'string'
        methods:'int'
        last_modified:'date'
        sip_instance:'string'
        attr:'string'
        kv_store: 'string'
      registrant:
        id:'int'
        registrar:'string'
        proxy:'string'
        aor:'string'
        third_party_registrant:'string'
        username:'string'
        password:'string'
        binding_URI:'string'
        binding_params:'string'
        expiry:'int'
        forced_socket:'string'
      presentity:
        id:'int'
        # index
        username:'string'
        domain:'string'
        event:'string'
        etag:'string'
        # data
        expires:'int'
        received_time:'int'
        body:'string' # binary
        extra_hdrs:'string' # binary
        sender:'string'
      active_watchers:
        id:'int'
        # index
        presentity_uri:'string'
        callid:'string'
        to_tag:'string'
        from_tag:'string'
        # data
        watcher_username:'string'
        watcher_domain:'string'
        to_user:'string'
        to_domain:'string'
        event:'string'
        event_id:'string'
        local_cseq:'int'
        remote_cseq:'int'
        contact:'string'
        record_route:'string'
        expires:'int'
        status:'int'
        reason:'string'
        version:'int'
        socket_info:'string'
        local_contact:'string'
        sharing_tag: 'string'
      watchers:
        id:'int'
        # index
        presentity_uri:'string'
        watcher_username:'string'
        watcher_domain:'string'
        event:'string'
        # data
        status:'int'
        reason:'string'
        inserted_time:'int'
      pua:
        id:'int'
        pres_uri:'string'
        pres_id:'string'
        event:'int'
        expires:'int'
        desired_expires:'int'
        flag:'int'
        etag:'string'
        tuple_id:'string'
        watcher_uri:'string'
        to_uri:'string'
        call_id:'string'
        to_tag:'string'
        from_tag:'string'
        cseq:'int'
        record_route:'string'
        contact:'string'
        remote_contact:'string'
        version:'int'
        extra_headers:'string'

quote_value
-----------

Convert a JavaScript value `x` into an OpenSIPS value of type `t`.

    quote_value = (t,x) ->
      # No value: no quoting.
      if not x?
        return ''

      # Expects numerical types => no quoting.
      if t is 'int' or t is 'double'
        # assert(parseInt(x).toString is x) if t is 'int' and typeof x isnt 'number'
        # assert(parseFloat(x).toString is x) if t is 'double' and typeof x isnt 'number'
        return x

      # assert(t is 'string')
      if typeof x is 'number'
        x = x.toString()
      if typeof x isnt 'string'
        x = JSON.stringify x
      # assert typeof x is 'string'

      # Assumes quote_delimiter = '"'
      return '"'+x.replace(/"/g, '""')+'"'

unquote_value
-------------

Convert an OpenSIPS value `x` of type `t` into a JavaScript value.

    unquote_value = (t,x) ->

      if not x?
        return null

      if x is '\u0000'
        return null

      if t is 'int'
        return parseInt(x)
      if t is 'double'
        return parseFloat(x)

      if t is 'date'
        try
          x = x.replace /[^\u0020-\u007f]/g, ''
          d = new Date x

Format expected by `db_str2time()` in `db/db_ut.c`.
Note: This requires opensips to be started in UTC, assuming toISOString() outputs using UTC (which it does in Node.js 0.4.11).

          return d.toISOString().replace 'T', ' '
        catch
          return null

      # string, blob, ...
      return x.toString()

    do ->
      assert = require 'assert'
      test_set =
        int: [
          0
          1
          234
        ]
        double: [
          0
          1
          234
          234.56
        ]
        date: [
          '2014-09-16 22:59:00.000Z'
          # 'Tue Dec  8 01:15:48 2015\n'
        ]
        ###
        string: [
          "foo"
          'bar " hello'
        ]
        other: [
          true
          false
          0
          1
          234
          234.56
          "foo"
          'bar " hello'
          [2,3,4]
          {a:2,b:'k'}
        ]
        ###

      for type, test_values of test_set
        for value in test_values
          assert.deepEqual (unquote_value type, quote_value type, value), value

    unquote_params = (k,v,table)->
      doc = {}
      names = k.split ','
      values = v.split ','
      types = column_types[table]

      doc[names[i]] = unquote_value(types[names[i]],values[i]) for i in [0...names.length]

      return doc


    field_delimiter = "\t"
    row_delimiter = "\n"

    line = (a) ->
      a.join(field_delimiter) + row_delimiter

    first_line = (types,c)->
      return line( types[col] for col in c )

    value_line = (types,n,hash,c)->
      if n is 'dr_rules'
        hash.ruleid ?= 1
        hash.routeid ?= ""
        hash.timerec ?= ""
        hash.priority ?= 1
        hash.attrs ?= '{}'
        hash.attrs = JSON.stringify(hash.attrs) unless typeof hash.attrs is 'string'
      if n is 'dr_carriers'
        hash.id ?= 1
        hash.flags ?= 0
        hash.attrs ?= '{}'
        hash.attrs = JSON.stringify(hash.attrs) unless typeof hash.attrs is 'string'
        hash.state ?= 0
      if n is 'dr_gateways'
        hash.id ?= 1
        hash.gwtype ?= 0
        hash.type = hash.gwtype
        hash.probe_mode ?= 0
        hash.strip ?= 0
        hash.attrs ?= '{}'
        hash.attrs = JSON.stringify(hash.attrs) unless typeof hash.attrs is 'string'
        hash.state ?= 0
      if n is 'dr_groups'
        hash.groupid = hash.outbound_route # alternatively set the "drg_grpid_col" parameter to "outbound_route"
      return line( quote_value(types[col], hash[col]) for col in c )

    exports.column_types = column_types
    exports.first_line = first_line
    exports.value_line = value_line
    exports.unquote_params = unquote_params
