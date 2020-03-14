FROM debian:buster-slim

LABEL description="kivitendo container"

MAINTAINER Hans-Jürgen Grimminger <info@ptec.de>

# Environment configuration options
#
# Change these values to your preferences
ENV locale de_DE
ENV postgres_version 11
ENV postgres_user postgres
ENV postgres_password postgres
ENV postgres_host localhost
ENV kivitendo_version release-3.5.5
ENV kivitendo_user kivitendo
ENV kivitendo_password kivitendo
ENV kivitendo_adminpassword admin123
ENV kivitendo_template company
ENV cups_user admin
ENV cups_password admin

ARG VERSION=3.5.5
ARG BUILD_DATE


# set debian locale
#
RUN apt-get update && apt-get install -y locales && rm -rf /var/lib/apt/lists/* \
    && localedef -i ${locale} -c -f UTF-8 -A /usr/share/locale/locale.alias ${locale}.UTF-8
ENV LANG ${locale}.utf8

# Install Packages
#
# sections: erp, tex, crm, other
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN apt-get -qq update && apt-get -y upgrade
RUN DEBIAN_FRONTEND=noninteractive apt install -y  \
  apache2 libarchive-zip-perl libclone-perl \
  libconfig-std-perl libdatetime-perl libdbd-pg-perl libdbi-perl \
  libemail-address-perl  libemail-mime-perl libfcgi-perl libjson-perl \
  liblist-moreutils-perl libnet-smtp-ssl-perl libnet-sslglue-perl \
  libparams-validate-perl libpdf-api2-perl librose-db-object-perl \
  librose-db-perl librose-object-perl libsort-naturally-perl \
  libstring-shellquote-perl libtemplate-perl libtext-csv-xs-perl \
  libtext-iconv-perl liburi-perl libxml-writer-perl libyaml-perl \
  libimage-info-perl libgd-gd2-perl libapache2-mod-fcgid \
  libfile-copy-recursive-perl libalgorithm-checkdigits-perl \
  libcrypt-pbkdf2-perl git libcgi-pm-perl libtext-unidecode-perl libwww-perl \
  aqbanking-tools poppler-utils libhtml-restrict-perl \
  libdatetime-set-perl libset-infinite-perl liblist-utilsby-perl \
  libdaemon-generic-perl libfile-flock-perl libfile-slurp-perl \
  libfile-mimeinfo-perl libpbkdf2-tiny-perl libregexp-ipv6-perl \
  libdatetime-event-cron-perl libexception-class-perl \
  libpath-tiny-perl \
  \
  texlive-base-bin texlive-latex-recommended texlive-fonts-recommended \
  texlive-latex-extra texlive-lang-german texlive-generic-extra texlive-xetex ghostscript lynx \
  \
  libapache2-mod-php php-gd php-imap php-mail php-mail-mime \
  php-pear php-mdb2 php-mdb2-driver-pgsql php-pgsql  \
  php-fpdf imagemagick fonts-freefont-ttf php-curl \
  libphp-jpgraph php-enchant aspell-de libset-crontab-perl  \
  \
  lsb-release exim4 supervisor sudo gnupg \
  mc


# Install PostgreSQL client
#
# Add PostgreSQL's PGP key & repository.
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7FCC7D46ACCC4CF8
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
# Install client
RUN DEBIAN_FRONTEND=noninteractive apt-get update &&\
    apt-get install -y \
    postgresql-client-${postgres_version} 

#
# Add CUPS printing system
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y  \
  cups cups-client cups-bsd \
  cups-filters \
  foomatic-db-compressed-ppds \
  printer-driver-all \
  openprinting-ppds \
  hpijs-ppds \
  hp-ppd \
  hplip \
  whois smbclient

# Add printer administrator and disable sudo password checking
RUN useradd \
  --groups=sudo,lp,lpadmin \
  --create-home \
  --home-dir=/home/${cups_user} \
  --shell=/bin/bash \
  --password=$(mkpasswd ${cups_password}) \
  ${cups_user} \
  && sed -i '/%sudo[[:space:]]/ s/ALL[[:space:]]*$/NOPASSWD:ALL/' /etc/sudoers

# Don't switch to https
RUN echo "DefaultEncryption Never" >> /etc/cups/cupsd.conf

# Configure CUPS to be reachable from outside
RUN /usr/sbin/cupsd \
  && while [ ! -f /var/run/cups/cupsd.pid ]; do sleep 1; done \
  && cupsctl --remote-admin --remote-any --share-printers \
  && kill $(cat /var/run/cups/cupsd.pid)

VOLUME  ["/etc/cups"]
EXPOSE 631/tcp 631/udp



# Add Kivitendo
#
# Kivitendo erp & crm download from git repositories
RUN cd /var/www/ && git clone https://github.com/kivitendo/kivitendo-erp.git
RUN cd /var/www/ && git clone https://github.com/kivitendo/kivitendo-crm.git
RUN cd /var/www/kivitendo-erp && git checkout ${kivitendo_version} && ln -s ../kivitendo-crm/ crm
# crm modifications
RUN cd /var/www/ && sed -i '$adocument.write("<script type='text/javascript' src='crm/js/ERPplugins.js'></script>")' kivitendo-erp/js/kivi.js
RUN cd /var/www/kivitendo-erp/menus/user && ln -s ../../../kivitendo-crm/menu/10-crm-menu.yaml 10-crm-menu.yaml
RUN cd /var/www/kivitendo-erp/sql/Pg-upgrade2-auth && ln -s  ../../../kivitendo-crm/update/add_crm_master_rights.sql add_crm_master_rights.sql
RUN cd /var/www/kivitendo-erp/locale/de && mkdir -p more && cd more && ln -s ../../../../kivitendo-crm/menu/t8e/menu.de crm-menu.de && ln -s ../../../../kivitendo-crm/menu/t8e/menu-admin.de crm-menu-admin.de
#
# Set directory permissions
#
RUN mkdir /var/www/kivitendo-erp/webdav /var/www/kivitendo-erp/kivi_documents
#
RUN chown -R www-data:www-data /var/www
RUN chmod u+rwx,g+rx,o+rx /var/www
RUN find /var/www -type d -exec chmod u+rx,g+rx,o+rx {} +
RUN find /var/www -type f -exec chmod u+r,g+r,o+r {} +

RUN chmod -R u+w,g+w /var/www/kivitendo-erp/users \
                     /var/www/kivitendo-erp/spool \
                     /var/www/kivitendo-erp/templates \
                     /var/www/kivitendo-erp/kivi_documents \
                     /var/www/kivitendo-erp/webdav


# Expose Volumes
#
VOLUME  ["/var/www/kivitendo-erp/templates/$kivitendo_template", \
         "/var/www/kivitendo-erp/config", \
         "/var/www/kivitendo-erp/users", \
         "/var/www/kivitendo-erp/webdav", \
         "/var/www/kivitendo-erp/kivi_documents"]


# Apache configuration
#
# set modules
RUN a2enmod fcgid ssl
# crm:
RUN a2enmod cgi
# Set apache site config
COPY apache-kivitendo.conf /etc/apache2/sites-available/kivitendo.conf
RUN a2ensite kivitendo && a2dissite 000-default
#
# expose ports of apache
EXPOSE 80 443
 


# Supervisord configuration & scripts
#
COPY supervisord*.conf /etc/supervisor/conf.d/
COPY *.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh


ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Start supervisord to execute all services
CMD ["/usr/local/bin/start.sh"]

