quote = require '../quote'

@list = (rows,req,t) ->
  t ?= req.query.t
  types = quote.column_types[t]
  columns = req.query.c.split ','
  hosts = {}
  lines = []
  header = quote.first_line(types,columns)
  for row in rows
    do (row) ->
      host = row.key[0]
      if row.value.interfaces?
        hosts[host] = row.value
      else
        ipv4 = hosts[host]?.interfaces.primary?.ipv4
        if ipv4?
          row.value.binding_URI = row.value.binding_URI.replace host, ipv4
        lines.push quote.value_line types, t, row.value, columns
  if lines.length is 0
    ''
  else
    header + lines.join ''
