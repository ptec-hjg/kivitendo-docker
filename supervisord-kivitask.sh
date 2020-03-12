#!/bin/bash

# Exit immediately if a simple command exits with a non-zero status
set -e


#wait for postgres container to startup
until psql "host=$postgres_host user=$postgres_user password=$postgres_password" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 30
done

#wait for kivitendo_auth db to be created by user
while ! psql "host=$postgres_host user=$postgres_user password=$postgres_password" -c "SELECT datname FROM pg_database;" | egrep kivitendo_auth 
do
  >&2 echo "kivitendo_auth is unavailable - sleeping"
  sleep 30
done

# Patch task_server to run in foreground mode
if ! cat /var/www/kivitendo-erp/scripts/task_server.pl | grep -q "foreground"; then
  echo "patching task_server.pl"
  sed -i "/progname   => 'kivitendo-background-jobs'.*/a \
	foreground    => 1,\
" /var/www/kivitendo-erp/scripts/task_server.pl
fi


# Starting the service
exec su -p www-data -s /bin/sh -c "/var/www/kivitendo-erp/scripts/task_server.pl start"

