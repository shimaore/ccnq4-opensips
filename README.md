OpenSIPS for CCNQ4
------------------

- Runs in Docker.
- Runs with mediaproxy-dispatcher embedded.
- Managed by supervisord.
- No fancy `list` etc. in CouchDB (they aren't cached anyhow).
- Need to set CONFIG to locate configuration file.
- Support registrant restart via `royal-thing`.
- Need to provide `local/ca.pem` for authentication.
- Optionally need to set `PASSPORT` environment variable (e.g. "O:Kwaoo") to further authenticate clients.

Requires `tough-rate` >= 11.0.0 in order to support emergency call routing properly.
