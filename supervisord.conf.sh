#!/bin/bash
# env.SUPERVISOR_PORT Port number for Supervisord's HTTP server. Default: 5708.
DEFAULT_SUPERVISOR_PORT=5708
SUPERVISOR_PORT="${SUPERVISOR_PORT:-${DEFAULT_SUPERVISOR_PORT}}"
sed -e "s/SUPERVISORD_PORT/${SUPERVISOR_PORT}/" supervisord.conf.src > supervisord.conf
exec /usr/bin/supervisord -n
