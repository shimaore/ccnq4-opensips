quote = require '../quote'
@show = (doc,req,t) ->
  body = ''
  t ?= req.query.t
  types = quote.column_types[t]
  columns = req.query.c.split ','

  if doc?
    body = quote.first_line(types,columns) + quote.value_line(types,t,doc,columns)
  body

@list = (rows,req,t) ->
  t ?= req.query.t
  types = quote.column_types[t]
  columns = req.query.c.split ','
  lines = []
  header = quote.first_line(types,columns)
  for row in rows
    do (row) ->
      lines.push quote.value_line types, t, row.doc ? row.value, columns
  if lines.length is 0
    ''
  else
    header + lines.join ''
