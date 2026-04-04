#!/bin/bash

# Start asterisk in the background
/usr/sbin/asterisk -c -vvvv -g &

# Start the minitel server in the background
cd minitel-server && . .venv/bin/activate && python3 MinitelSrv.py &

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
