p_fun = (f) -> '('+f+')'
pkg = require '../../package.json'

ddoc =
  _id: "_design/#{pkg.name}-client"
  version: pkg.version
  language: 'javascript'
  views: {}

module.exports = ddoc

ddoc.views.gateways_by_domain =
  map: p_fun (doc) ->

    if doc.type? and doc.type is 'gateway'
      emit doc.sip_domain_name, doc

    if doc.type? and doc.type is 'host' and doc.sip_profiles?
      for name, rec of doc.sip_profiles
        do (rec) ->
          # for now we only generate for egress gateways
          if rec.egress_gwid?
            ip = rec.egress_sip_ip ? rec.ingress_sip_ip
            port = rec.egress_sip_port ? rec.ingress_sip_port+10000
            emit doc.sip_domain_name,
              account: ""
              gwid: rec.egress_gwid
              address: ip+':'+port
              gwtype: 0
              probe_mode: 0

    return

ddoc.views.rules_by_domain =
  map: p_fun (doc) ->
    if doc.type? and doc.type is 'rule'
      emit doc.sip_domain_name, doc
    return

ddoc.views.carriers_by_host =
  map: p_fun (doc) ->
    if doc.type? and doc.type is 'carrier'
      emit doc.host, doc
    return
