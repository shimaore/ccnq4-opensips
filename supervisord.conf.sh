#!/bin/bash
# env.SUPERVISOR_PORT Port number for Supervisord's HTTP server. Default: 5708.
DEFAULT_SUPERVISOR_PORT=5708
# env.SHARED_MEMORY Maximum shared memory used globally by OpenSIPS. Default: 64.
DEFAULT_SHARED_MEMORY=64
# env.PACKAGE_MEMORY Maximum package memory used by each OpenSIPS process. Default: 16.
DEFAULT_PACKAGE_MEMORY=16

SUPERVISOR_PORT="${SUPERVISOR_PORT:-${DEFAULT_SUPERVISOR_PORT}}"
SHARED_MEMORY="${SHARED_MEMORY:-${DEFAULT_SHARED_MEMORY}}"
PACKAGE_MEMORY="${PACKAGE_MEMORY:-${DEFAULT_PACKAGE_MEMORY}}"

sed -e "
  s/SUPERVISORD_PORT/${SUPERVISOR_PORT}/
  s/SHARED_MEMORY/${SHARED_MEMORY}/
  s/PACKAGE_MEMORY/${PACKAGE_MEMORY}/
" supervisord.conf.src > supervisord.conf
exec /usr/bin/supervisord -n
