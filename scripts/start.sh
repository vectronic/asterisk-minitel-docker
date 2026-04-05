#!/bin/bash

# Start asterisk in the background
/usr/sbin/asterisk -c -vvvv -g &

# Start the minitel server in the background
cd /minitel-server && . .venv/bin/activate && python3 MinitelSrv.py &

# Keep the container alive while any managed process is still running.
# This avoids restart loops when only one child exits.
wait
