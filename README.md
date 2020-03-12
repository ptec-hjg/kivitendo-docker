kivitendo-docker
================

Docker build files for kivitendo, an ERP system for the German market


# Table of Contents

- [Introduction](#introduction)
- [Changelog](Changelog.md)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Data Store](#data-store)
- [Maintenance](#maintenance)
    - [Printing](#printing)
    - [Backup](#backup)
- [Upgrading](#upgrading)

# Introduction

This Dockerfile and his accompanying files are used to build a docker image providing the popular ERP 
[kivitendo](http://www.kivitendo.de).

The image is based on debian (currently buster:slim) and will include Apache2 and all the necessary packages 
for kivitendo-erp and kivitendo-crm. For ease of
use a CUPS server is included to get printers configured and running as well as a kivitendo task_server background
worker.

A Postgresql database is NOT part of this docker image but must be supplied from a separate container 
(e.g. the official postgresql build). See below for instructions.

# Installation

I assume that you are working on your favourite linux box. So create a working directory to easily manage all 
your kivitendo containers & data.

```bash
mkdir ~/kivitendo
cd ~/kivitendo
```

Next, as mentioned above you need a running postgresql docker container to use kivitendo-docker.
We will use the official postgresql version 11 docker image, expose the standard postgresql port for outside communication
and tell the container where to hold the database data.

```bash
docker run --name postgres1 -d \
 -p 5432:5432 \
 -e "POSTGRES_PASSWORD=postgres" -e "POSTGRES_USER=postgres" -e "PGDATA=/var/lib/postgresql/data/pgdata1" \
 -v postgres1:/var/lib/postgresql/data/pgdata1 \
 postgres:11
```

To test if the postgresql server is working properly, try connecting to it with:

```bash
docker exec -it postgres1 psql -U  postgres db_ptec -c "SELECT 'successfully queried postgres container';"
```

If you need access to the database files later on you can link the postgres volume to your working directory like this:

```bash
ln -s /var/lib/docker/volumes/postgres1/_data /root/kivitendo/postgres1
```

I suppose that you are using a debian box, where docker stores it's volumes per default at /var/lib/docker/volumes.



Now it is time to get the kivitendo docker container up and running by issuing this command:

```bash
docker run --name kivid -d \
 --net host \
 -e "postgres_host=$(docker inspect -f {{.NetworkSettings.IPAddress}} $(docker ps --filter name=postgres1 -q)  )" \
 -e "postgres_user=postgres" -e "postgres_password=postgres" \
 -e "kivitendo_user=kivitendo" -e "kivitendo_password=kivitendo" \
 -e "kivitendo_adminpassword=admin123" \
 -e "kivitendo_template=company" \
 -e "cups_user=admin" -e "cups_password=admin" \
 -v kivid_templ:/var/www/kivitendo-erp/templates/company \
 -v kivid_config:/var/www/kivitendo-erp/config \
 -v kivid_webdav:/var/www/kivitendo-erp/webdav \
 -v kivid_documents:/var/www/kivitendo-erp/kivi_documents \
 -v /var/run/dbus:/var/run/dbus \
 -p 631:631 \
 -p 80:80 \
 ptec-hjg/kivitendo-docker:3.5.5
```

There are a lot of parameters and options you can set to suite your needs.
I will explain the most often used:

The '-e "postgres_ ..."' parameters tell our kivitendo how to connect to the already running postgres container and
what credential to use.

The '-e "kivitendo_user/password"' defines the kivitendo superuser needed to create and maintain your kivitendo databases.

The '-e "kivitendo_adminpassword"' is used for the administrative login to manage users, groups, databases and printers
within kivitendo.

The '-e "kivitendo_template"' parameter defines a directory for your printing layout configurations.

The '-e "cups_user/password"' credentials are used to manage your printers via the cups GUI.

All the '-v ...' parameters are used to get in touch with all those important directories within your kivitendo container.

The kivitendo web GUI and the cups GUI are exposed to their standard ports 80 and 631 respectively.



Alternately you can build the image by yourself. Just clone the git repository and perform a docker 'build'.
You may change the Dockerfile to better suite your preferences by editing the ENV values within.

```bash
git clone https://github.com/ptec-hjg/kivitendo-docker.git
cd kivitendo-docker
docker build -t="<name_of_your_container>" .
```

# Quick Start

As your kivitendo container is up now, you can go with this run-through to quickly get a working configuration.

Point your browser to the ip of your linux box
```bash
http://<ip_of_your_linux_box>
```

You will likely get an error message (Fehler 'Datenbank nicht erreichbar'), so you have to follow the link to
kivitendo's administrative interface. Use the above defined password 'admin123' (kivitendo_adminpassword) to login
 and perform the basic configuration:

'Datenbankadministration' | 'Neue Datenbank anlegen' (IP, port, Datenbankbenutzer & Passwort do have defaults): 'Anmelden'  
'Tabellen anlegen', 'Weiter'

'Benutzer, Mandanten und Benutzergruppen' | 'Neuer Benutzer'
  Benutzer: 'user1', Passwort: 'user1', Name: 'User 1', 'Speichern'

'Benutzer, Mandanten und Benutzergruppen' | 'Neuer Benutzergruppe'
  Name: 'Alle', check all heading checkboxes, move 'user1' into group, 'speichern'

'Datenbankadministration' | 'Neue Datenbank anlegen'
  Datenbankanmeldung: 'anmelden' 
    'Neue Datenbank anlegen' 'db_mand1', SKR03, Soll-Versteuerung, Bestandsmethode, Bilanzierung, 'anlegen'

'Benutzer, Mandanten und Benutzergruppen' | 'Neuer Mandant'
  'Mandantname' 'Mand1', Standardmandant: j, Datenbankname: 'db_mand1', Zugriff: 'user1', 
    Gruppen: 'Alle'+'Vollzugriff', 'speichern'

'System' | 'Zum Benutzerlogin'

Now you can login as user 'user1' with the password 'user1' on  'Mand1'.

To let kivitendo create some important CRM database content, just load a mask from the crm:
  CRM | Administration | Mandant

Congratulation, you have a running kivitendo docker container to play with.


# Configuration

## Data Store

To make sure that the data stored in the kivitendo / postgresql database is not lost when the image is 
stopped and started again, we defined all those '-v ...' options above.

To link those volumes to your working directory, issue these commands:

```bash
ln -s /var/lib/docker/volumes/kivid_templ/_data /root/kivitendo/kivid_templ
ln -s /var/lib/docker/volumes/kivid_config/_data /root/kivitendo/kivid_config
ln -s /var/lib/docker/volumes/kivid_users/_data /root/kivitendo/kivid_users
ln -s /var/lib/docker/volumes/kivid_webdav/_data /root/kivitendo/kivid_webdav
```


# Maintenance

## Printing

To configure a printer for your kivitendo system, you may use the CUPS GUI:

```bash
http://<ip_of_your_linux_box>:631
```

Configuring the CUPS system is beyond this guide, please take a look at
[Debian System Printing](https://wiki.debian.org/SystemPrinting).

When adding a printer you may have to enter administrative credentials which you had defined 
using the '-e "cups_user/password"' parameters.


## Backup

You can backup your databases on your debian host like this:

```bash
docker exec -i postgres1 pg_dump -U postgres -C  kivitendo_auth > ./kivitendo_auth-`date +%Y%m%d_%R`.sql
docker exec -i postgres1 pg_dump -U postgres -C  db_mand1 > ./db_mand1-`date +%Y%m%d_%R`.sql
```

(assuming that 'db_mand1' is your client database name)

To restore the databases from your backup you have to drop (delete) the currently running databases and
then feed postgres with the saved sql data.
```bash
docker exec -i postgres1 dropdb -U postgres kivitendo_auth
docker exec -i postgres1 psql -U postgres postgres  < ./kivitendo_auth-20201122_16:20.sql
docker exec -i postgres1 dropdb -U postgres db_mand1
docker exec -i postgres1 psql -U postgres postgres  < ./db_mand1-20201122_16:30.sql
```




# Upgrading

To upgrade to a newer releases, simply follow these 3 steps.

- **Step 1**: Stop the currently running container

```bash
docker stop kivid
```

- **Step 2**: Update the docker image

```bash
docker pull ptec-hjg/kivitendo-docker:latest
```

- **Step 3**: Start the image and run the container

```bash
docker run --name kivid -d \
 --net host \
 -e "postgres_host=$(docker inspect -f {{.NetworkSettings.IPAddress}} $(docker ps --filter name=postgres1 -q)  )" \
 -e "postgres_user=postgres" -e "postgres_password=postgres" \
 -e "kivitendo_user=kivitendo" -e "kivitendo_password=kivitendo" \
 -e "kivitendo_adminpassword=admin123" \
 -e "kivitendo_template=company" \
 -e "cups_user=admin" -e "cups_password=admin" \
 -v kivid_templ:/var/www/kivitendo-erp/templates/company \
 -v kivid_config:/var/www/kivitendo-erp/config \
 -v kivid_webdav:/var/www/kivitendo-erp/webdav \
 -v kivid_documents:/var/www/kivitendo-erp/kivi_documents \
 -v /var/run/dbus:/var/run/dbus \
 -p 631:631 \
 -p 80:80 \
 ptec-hjg/kivitendo-docker:latest
```

Please use kivitendo's administrative login first to go through database upgrades.
