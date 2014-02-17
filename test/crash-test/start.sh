#!/bin/bash
killall opensips

(sleep 3 && nc -u localhost 5067 < packet.txt) &

HERE="`pwd`"
cat startup.txt - | { cd ../../../opensips && gdb --args /usr/sbin/opensips -D -E -f "$HERE/opensips.cfg"; }
