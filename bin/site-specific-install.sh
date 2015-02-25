#!/bin/sh

PARENT_SCRIPT_URL=https://github.com/mysociety/commonlib/blob/master/bin/install-site.sh

misuse() {
  echo The variable $1 was not defined, and it should be.
  echo This script should not be run directly - instead, please run:
  echo   $PARENT_SCRIPT_URL
  exit 1
}

# Strictly speaking we don't need to check all of these, but it might
# catch some errors made when changing install-site.sh

[ -z "$DIRECTORY" ] && misuse DIRECTORY
[ -z "$UNIX_USER" ] && misuse UNIX_USER
[ -z "$REPOSITORY" ] && misuse REPOSITORY
[ -z "$REPOSITORY_URL" ] && misuse REPOSITORY_URL
[ -z "$BRANCH" ] && misuse BRANCH
[ -z "$SITE" ] && misuse SITE
[ -z "$DEFAULT_SERVER" ] && misuse DEFAULT_SERVER
[ -z "$HOST" ] && misuse HOST
[ -z "$DISTRIBUTION" ] && misuse DISTRIBUTION
[ -z "$DISTVERSION" ] && misuse DISTVERSION

apt-get install -qq -y python-flup gunicorn >/dev/null

install_nginx

install_website_packages

install_postgis

if [ x"$DISTRIBUTION" = x"ubuntu" ] && [ x"$DISTVERSION" = x"trusty" ]
then
    # On trusty, the database user will need to be a superuser so that
    # it can create the PostGIS extension; we'll drop that privilege
    # afterwards:
    add_postgresql_user --superuser
else
    add_postgresql_user
fi

make_log_directory

su -l -c "$REPOSITORY/bin/install-as-user '$UNIX_USER' '$HOST' '$DIRECTORY'" "$UNIX_USER"

if [ x"$DISTRIBUTION" = x"ubuntu" ] && [ x"$DISTVERSION" = x"trusty" ]
then
    sudo -u postgres psql -c "ALTER USER $UNIX_USER WITH NOSUPERUSER"
fi

install_sysvinit_script

add_website_to_nginx

echo Installation complete - you should now be able to view the site at:
echo   http://$HOST/
