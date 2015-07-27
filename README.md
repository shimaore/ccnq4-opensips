OpenSIPS for CCNQ4
------------------

- Runs in Docker.
- Managed by supervisord.
- No fancy `list` etc. in CouchDB (they aren't cached anyhow).
- Need to set CONFIG to locate configuration file.
- Support registrant restart via `royal-thing`.

Requires `tough-rate` >= 11.0.0 in order to support emergency call routing properly.
