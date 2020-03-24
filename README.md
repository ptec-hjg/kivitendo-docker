Welcome to kivitendo
====================

kivitendo is a web-based application for customer addresses, products, warehouse management, quotations 
and commercial financial accounting for the German market.  

You can use it to do your office work both on the intranet and on the Internet. As an open source solution, 
it is the first choice if you want to add special forms, documents, tasks or functions that you want to use 
to meet your individual requirements.

To learn more about kivitendo please visit the maintainers page at [kivitendo.de](http://www.kivitendo.de/index.html)


# Table of Contents

- [Introduction](#introduction)
- [Changelog](Changelog.md)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
    - [Data Store](#data-store)
    - [Printing](#printing)
- [Maintenance](#maintenance)
    - [Backup](#backup)
    - [Stopping and starting the container](#Stopping-and-starting-the-container)
    - [Upgrading](#upgrading)
- [Manage customizations](#manage-customization)

# Introduction

This Dockerfile and its accompanying files are used to build a docker image providing the popular ERP 
[kivitendo.de](http://www.kivitendo.de/index.html).

The image is based on debian (currently buster:slim) and will include Apache2 and all the necessary packages 
for kivitendo-erp and kivitendo-crm. For ease of
use a CUPS server is included to get printers configured and running as well as a kivitendo task_server background
worker.

A Postgresql database is NOT part of this docker image but must be supplied from a separate container 
(e.g. the official postgresql build). See below for instructions.

# Installation

A complete kivitendo application consists out of a kivitendo docker image and a PostgreSQL SQL server image. 

I assume that you are working on your favourite linux box as your docker host (e.g. your NAS) where to 
store all your database, configuration and email files used by kivitendo.  

To deploy a new application, first create a working directory to easily manage all 
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
docker exec -it postgres1 psql -U  postgres postgres -c "SELECT 'successfully queried postgres container';"
```

If you need access to the database files later on you can link the postgres volume to your working directory like this:

```bash
ln -s /var/lib/docker/volumes/postgres1/_data ~/kivitendo/postgres1
```

Again I suppose that you are using a debian box, where docker stores its volumes per default at /var/lib/docker/volumes.



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
 ptechjg/kivitendo-docker:latest
```

There are a lot of parameters and options you can set to suite your needs.
I will explain the most often used:

The '-e "postgres_ ..."' parameters tell our kivitendo how to connect to the already running postgres container and
what credentials to use.

The '-e "kivitendo_user/password"' defines the kivitendo superuser needed to create and maintain your kivitendo databases.

The '-e "kivitendo_adminpassword"' is used for the administrative login to manage users, groups, databases and printers
within kivitendo.

The '-e "kivitendo_template"' parameter defines a directory for your printing layout configurations.

The '-e "cups_user/password"' credentials are used to manage your printers via the cups GUI.

All the '-v ...' parameters are used to get in touch with all those important directories within your kivitendo container.

The kivitendo web GUI and the cups GUI are exposed to their standard ports 80 and 631 respectively.



For further customizations you can build the image by yourself. Just clone the git repository and perform a docker 'build'.
In a first step you may change the Dockerfile to better suite your preferences by editing the ENV values within.

```bash
git clone https://github.com/ptec-hjg/kivitendo-docker.git
cd kivitendo-docker
docker build -t="<name_of_your_container>" .
```

# Quick Start

As your kivitendo container is up now, you can go with this run-through to quickly get a working configuration.

The kivitendo container will be available by browsing to the ip of your docker host:
```bash
http://<ip_of_your_linux_box>
```

You will likely get an error message (Fehler 'Datenbank nicht erreichbar'), so you have to follow the link to
kivitendos administrative interface. Use the above defined password 'admin123' (kivitendo_adminpassword) to login
 and perform the basic configuration:

- Create kivitendo database  
'Datenbankadministration' | 'Neue Datenbank anlegen' (IP, port, Datenbankbenutzer & Passwort do have defaults): 'Anmelden'  
'Tabellen anlegen', 'Weiter'

- Create user  
'Benutzer, Mandanten und Benutzergruppen' | 'Neuer Benutzer'
  Benutzer: 'user1', Passwort: 'user1', Name: 'User 1', 'Speichern'

- Create usergroup  
'Benutzer, Mandanten und Benutzergruppen' | 'Neuer Benutzergruppe'
  Name: 'Alle', check all heading checkboxes, move 'user1' into group, 'speichern'

- Create client database  
'Datenbankadministration' | 'Neue Datenbank anlegen'
  Datenbankanmeldung: 'anmelden' 
    'Neue Datenbank anlegen' 'db_mand1', SKR03, Soll-Versteuerung, Bestandsmethode, Bilanzierung, 'anlegen'

- Create client  
'Benutzer, Mandanten und Benutzergruppen' | 'Neuer Mandant'
  'Mandantname' 'Mand1', Standardmandant: j, Datenbankname: 'db_mand1', Zugriff: 'user1', 
    Gruppen: 'Alle'+'Vollzugriff', 'speichern'

- Go to the regular login screen  
'System' | 'Zum Benutzerlogin'

Now you can login as user 'user1' with the password 'user1' on  'Mand1'.

To let kivitendo create some important CRM database content, just load a screen from the crm:  
  CRM | Administration | Mandant

Congratulation, you have a running kivitendo docker container to play with.


# Configuration

## Data Store

To make sure that the data stored in the kivitendo / postgresql database is not lost when the image is 
stopped and started again, we defined all those '-v ...' options above.

To link those volumes to your working directory for easy access, issue these commands:

```bash
ln -s /var/lib/docker/volumes/kivid_templ/_data ~/kivitendo/kivid_templ
ln -s /var/lib/docker/volumes/kivid_config/_data ~/kivitendo/kivid_config
ln -s /var/lib/docker/volumes/kivid_documents/_data ~/kivitendo/kivid_documents
ln -s /var/lib/docker/volumes/kivid_webdav/_data ~/kivitendo/kivid_webdav
```


## Printing

To configure a printer for your kivitendo system, you may use the CUPS GUI:

```bash
http://<ip_of_your_linux_box>:631
```

Configuring the CUPS system is beyond this guide, please take a look at
[Debian System Printing](https://wiki.debian.org/SystemPrinting).

When adding a printer you may have to enter administrative credentials which you had defined 
using the '-e "cups_user/password"' parameters.

It can be useful to 'Set Allowed Users' to 'root www-data print'.

If you want access your CUPS configuration from outside your kivitendo container (e.g. for backup reason) you can add
this line to your command with which you start the kivitendo container:

```bash
 -v kivid_cups:/etc/cups \
```

## WebDAV

You can access the kivitendo webdav directory via webdav (sic!) like this:

```bash
http://<ip_of_your_linux_box>/webdav
```

The default username and password are 'webdav' and 'webdav'.  
You can change the defaults to your own using these environment settings:

```bash
 -e "webdav_user=webdav" \
 -e "webdav_password=webdav" \
```


# Maintenance


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

## Stopping and starting the container

To stop the container use:

```bash
$ docker stop kivid
```

To start the container again:

```bash
$ docker start kivid
```


## Upgrading

Upgrading a kivitendo Docker container is actually a matter of stopping and deleting the container
, downloading the most recent version of the image and starting a container again. The container will 
take care of updating the database structure to the newest version if necessary.

**IMPORTANT!** Do not delete any of the volumes, only the container.


To upgrade to a newer releases, simply follow these steps.

- **Step 1**: Stop the currently running container

```bash
docker stop kivid
```

- **Step 2**: Remove the container

```bash
docker rm kivid
```

- **Step 3**: Get the new Docker image version

```bash
docker pull ptechjg/kivitendo-docker:latest
```

- **Step 4**: Start the image and run the container

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
 ptechjg/kivitendo-docker:latest
```

Please use kivitendos administrative login first to let kivitendo upgrade your databases.

# Manage Customizations

A lot of people do not use the stock kivitendo but just pull it from the official repository and add their
own customizations, without pushing back to the main repository.

How do you manage those customizations with this docker image, and how do you apply your changes
to the next version of the image?

For this we use the git patch commands, creating appropriate patch files for all your changes, and applying those 
patches when a new version of the docker image is run.

To define the name of your own branch of kivitendo you can use this environment setting when starting the container:

```bash
 -e "kivitendo_branch=customize" \
```

To get access to and feed the container with patch files, you have to connect to this docker volume:

```bash
 -v kivid_patches:/var/www/patches \
```

As you have done with the other volumes you may create a symbolic link in your working directory for ease of use:

```bash
ln -s /var/lib/docker/volumes/kivid_patches/_data ~/kivitendo/kivid_patches
```


To do your customizatio you would typically work within your running container. To jump into it use:

```bash
docker exec -it kivid bash
```

Kivitendo is located as usual at /var/www/kivitendo-erp (the crm is at /var/www/kivitendo-crm), and you are
already within your working branch as defined above ('customize' as default).

When all your changes are done, you have to use this command to create patch files:

```bash
git commit -a -m "<your descriptive comment>"
git format-patch master -o /var/www/patches/erp
```

Git will create patch files reflecting your changes into the named directory.

And that's it.  
The next time you pull and start a new version of this docker image, the
container will automagically apply your patches to kivitendo, as long as you did provide the above mentioned
patch volume at the start of your container.

To create patch files for the kivitendo-crm please use '/var/www/patches/crm' as output directory for
the above 'git format-patch' command.

You should check the appropriate log files generated within the patch directories to be sure that your
patches are proccessed successfully.  
Any conflicts have to be resolved by you.

