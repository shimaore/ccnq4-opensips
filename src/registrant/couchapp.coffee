p_fun = (f) -> '('+f+')'
pkg = require '../../package.json'
id = "#{pkg.name}-#{pkg.version}-registrant"

ddoc =
  _id: "_design/#{id}"
  version: pkg.version
  language: 'javascript'
  views: {}
  lib: {}

module.exports = ddoc

ddoc.views.registrant_by_host =
  map: p_fun (doc) ->

    if doc.type? and doc.type is 'number' and doc.registrant_password? and doc.registrant_host? and doc.registrant_remote_ipv4?
      value =
        registrar: "sip:#{doc.registrant_remote_ipv4}"
        # proxy: null
        aor: "sip:00#{doc.number}@#{doc.registrant_remote_ipv4}"
        # third_party_registrant: null
        username: "00#{doc.number}"
        password: doc.registrant_password
        # binding_URI: "sip:00#{doc.number}@#{p.interfaces.primary.ipv4 ? p.host}:5070"
        # binding_params: null
        expiry: doc.registrant_expiry ? 86400
        # forced_socket: null

      hosts = doc.registrant_host
      if typeof hosts is 'string'
        hosts = [hosts]

      for host in hosts
        [hostname,port] = host.split /:/
        port ?= 5070
        value.binding_URI = "sip:00#{doc.number}@#{hostname}:#{port}"
        emit [hostname,1], value

    if doc.type? and doc.type is 'host' and doc.applications.indexOf('applications/registrant') >= 0
      # Make sure these records show up at the top
      emit [doc.host,0], interfaces:doc.interfaces

    return
