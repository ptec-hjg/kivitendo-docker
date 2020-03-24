#!/bin/bash

# Starting the apache2 server
a2enmod fcgid
a2enmod dav*
source /etc/apache2/envvars
exec apache2 -D FOREGROUND
