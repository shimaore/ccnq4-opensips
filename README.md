OpenSIPS for CCNQ4
------------------

- Runs in Docker.
- Runs with mediaproxy-dispatcher embedded.
- Managed by supervisord.
- No fancy `list` etc. in CouchDB (they aren't cached anyhow).
- Need to provide `local/ca.pem` for authentication.
- Optionally need to set `PASSPORT` environment variable (e.g. "O:Kwaoo") to further authenticate clients.
