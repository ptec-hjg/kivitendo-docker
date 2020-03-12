#!/bin/bash

# Exit immediately if a simple command exits with a non-zero status
set -e

# Starting the service
exec /usr/sbin/cups-browsed --autoshutdown=Off


