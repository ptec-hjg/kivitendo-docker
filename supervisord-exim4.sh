#!/bin/bash

# Exit immediately if a simple command exits with a non-zero status
set -e

# Starting the service
#exec service exim4 start
exec /usr/sbin/exim4 -bdf -v -q30m


