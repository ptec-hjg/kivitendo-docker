#!/bin/sh
set -eu

# version_greater A B returns whether A > B
version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 -k4,4 | head -n 1)" != "$1" ]
}

# return true if specified directory is empty
directory_empty() {
    [ -z "$(ls -A "$1/")" ]
}

run_as() {
    if [ "$(id -u)" = 0 ]; then
        su -p www-data -s /bin/sh -c "$1"
    else
        sh -c "$1"
    fi
}

#wait for postgres container to startup
until psql "host=$postgres_host user=$postgres_user password=$postgres_password" -c '\q'; do
	>&2 echo "Postgres is not yet available - waiting ..."
	sleep 30
done

# first time run ?
if [ -f /tmp/container_first ]; then
  echo "Kivitendo container first run"

  rm /tmp/container_first

  echo "... checking out custom git branch ${kivitendo_branch} & apply patches"
  cd /var/www/kivitendo-erp
  git checkout -b ${kivitendo_branch}
  if [ -f /var/www/patches/erp/*.patch ]; then git am /var/www/patches/erp/*.patch > /var/www/patches/erp.log; fi 

  cd /var/www/kivitendo-crm
  git checkout -b ${kivitendo_branch}
  if [ -f /var/www/patches/crm/*.patch ]; then git am /var/www/patches/crm/*.patch > /var/www/patches/crm.log; fi 

  echo "... setting mailer configuration"
  # exim4 can't bind to ::1, so update configuration
  sed -i "s/dc_local_interfaces.*/dc_local_interfaces='127.0.0.1 ; '/" /etc/exim4/update-exim4.conf.conf
  update-exim4.conf
fi

if [ ! -f /var/www/kivitendo-erp/config/kivitendo.conf ]; then
  echo "Kivitendo configuration directory is empty, so start initialization"


  echo "... creating kivitendo.conf"
  cp /var/www/kivitendo-erp/config/kivitendo.conf.default /var/www/kivitendo-erp/config/kivitendo.conf

  sed -i "s/admin_password.*/admin_password = $kivitendo_adminpassword/" /var/www/kivitendo-erp/config/kivitendo.conf

  sed -i "/^# users/,/^\[authentication/ s/localhost/$postgres_host/" /var/www/kivitendo-erp/config/kivitendo.conf
  sed -i "/^# users/,/^\[authentication/ s/user     =.*/user     = $kivitendo_user/" /var/www/kivitendo-erp/config/kivitendo.conf
  sed -i "/^# users/,/^\[authentication/ s/password =.*/password = $kivitendo_password/" /var/www/kivitendo-erp/config/kivitendo.conf

  sed -i "/testing/,/^\[devel/ s/localhost/$postgres_host/" /var/www/kivitendo-erp/config/kivitendo.conf
  sed -i "/testing/,/^\[devel/ s/^user               =.*/user               = $kivitendo_user/" /var/www/kivitendo-erp/config/kivitendo.conf
  sed -i "/testing/,/^\[devel/ s/^password           =.*/password           = $kivitendo_password/" /var/www/kivitendo-erp/config/kivitendo.conf
  sed -i "/testing/,/^\[devel/ s/^superuser_user     =.*/superuser_user     = $postgres_user/" /var/www/kivitendo-erp/config/kivitendo.conf
  sed -i "/testing/,/^\[devel/ s/^superuser_password =.*/superuser_password = $postgres_password/" /var/www/kivitendo-erp/config/kivitendo.conf

  sed -i "s%^# document_path =.*%document_path = /var/www/kivitendo-erp/kivi_documents%" /var/www/kivitendo-erp/config/kivitendo.conf


  echo "... creating database user & extensions"
  # create user & extension
  psql "host=$postgres_host user=$postgres_user password=$postgres_password" --command "CREATE EXTENSION IF NOT EXISTS plpgsql;"  >> /var/log/postgres_config.log
  psql "host=$postgres_host user=$postgres_user password=$postgres_password" --command "CREATE USER ${kivitendo_user} WITH SUPERUSER INHERIT CREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS  ENCRYPTED PASSWORD '${kivitendo_password}';" >> /var/log/postgres_config.log
  #psql "host=$postgres_host user=$postgres_user password=$postgres_password" --command "CREATE USER ${kivitendo_user} WITH CREATEDB CREATEROLE CREATEUSER  ENCRYPTED PASSWORD '${kivitendo_password}';" >> /var/log/postgres_config.log

else
  echo "Kivitendo configuration directory appears to contain a valid configuration; Skipping initialization"
fi


if ! cat /var/www/kivitendo-erp/scripts/task_server.pl | grep -q "foreground"; then
  echo "patching task_server.pl"
  sed -i "/progname   => 'kivitendo-background-jobs'.*/a \
	foreground    => 1,\
" /var/www/kivitendo-erp/scripts/task_server.pl
fi


if [ ! -d /var/www/kivitendo-erp/templates/$kivitendo_template ]; then
    echo "... creating print template directory [$kivitendo_template]"
    mkdir -p /var/www/kivitendo-erp/templates/$kivitendo_template
fi
if [ -n "$(find "/var/www/kivitendo-erp/templates/$kivitendo_template" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
    echo "... filling print template directory [$kivitendo_template]"
    cp -a /var/www/kivitendo-erp/templates/print/RB/* /var/www/kivitendo-erp/templates/$kivitendo_template
    chown -R www-data:www-data /var/www/kivitendo-erp/templates/$kivitendo_template
else
    echo "... print template directory [$kivitendo_template] already populated"
fi

#Check Kivitendo installation
echo "... checking kivitendo configuration"
cd /var/www/kivitendo-erp/ && perl /var/www/kivitendo-erp/scripts/installation_check.pl

echo "now executing $@"

exec "$@"
