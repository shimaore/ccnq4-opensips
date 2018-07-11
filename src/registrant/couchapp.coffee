p_fun = (f) -> '('+f+')'
pkg = require '../../package.json'
id = "#{pkg.name}-#{pkg.version}-registrant"

module.exports = (cfg) ->
  ddoc =
    _id: "_design/#{id}"
    id: id
    package: pkg.name
    version: pkg.version
    language: 'javascript'
    views: {}
    lib: {}
    views:
      registrant_by_host:
        map: registrant_by_host_map.replace 'DEFAULT_REGISTRANT_EXPIRY', cfg.default_registrant_expiry ? 86413

registrant_by_host_map = p_fun (doc) ->

    return if doc.disabled

    domain = doc.registrant_domain
    domain ?= doc.registrant_remote_ipv4 # legacy

    if doc.type? and doc.type is 'number' and doc.registrant_password? and doc.registrant_host? and domain?

      username = doc.registrant_username
      unless username?
        # backward compatible
        silly_prefix = doc.registrant_prefix ? '00'
        username = "#{silly_prefix}#{doc.number}"

      aor = "sip:#{username}@#{domain}"
      rand = 7
      rand += aor.charCodeAt i for i in [0...aor.length]

      expiry = doc.registrant_expiry ? DEFAULT_REGISTRANT_EXPIRY

      # Randomize the expiry time by as much as 5%
      rand %= (expiry // 10) + 1
      expiry += rand - rand // 2

      value =
        registrar: "sip:#{domain}"
        # proxy: null
        aor: aor
        # third_party_registrant: null
        username: username
        password: doc.registrant_password
        # binding_URI: "sip:00#{doc.number}@#{p.interfaces.primary.ipv4 ? p.host}:5070"
        # binding_params: null
        expiry: expiry
        # forced_socket: null

      value.proxy = doc.registrant_proxy if doc.registrant_proxy?
      value.third_party_registrant = doc.registrant_from if doc.registrant_from?

      hosts = doc.registrant_host
      if typeof hosts is 'string'
        hosts = [hosts]

      for host in hosts
        [hostname,port] = host.split /:/
        port ?= 5070
        value.binding_URI = "sip:#{username}@#{hostname}:#{port}"
        value.forced_socket = "udp:#{doc.registrant_socket}"
        emit [hostname,1], value

    if doc.type? and doc.type is 'host' and doc.applications.indexOf('applications/registrant') >= 0
      # Make sure these records show up at the top
      emit [doc.host,0], interfaces:doc.interfaces

    return
