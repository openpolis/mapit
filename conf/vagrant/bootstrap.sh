#!/usr/bin/env bash

# This script will install the application on a clean install of
# squeeze/wheezy or Ubuntu precise/trusty.

# script is executed as root, and executes the
# provisioning for a vagrant box (uses vagrant user)
# To use the script for provisioning on other environments,
# pleas copy and adapt.


# some useful functions and variables definitions
set -e
error_msg() { printf "\033[31m%s\033[0m\n" "$*"; }
notice_msg() { printf "\033[33m%s\033[0m " "$*"; }
done_msg() { printf "\033[32m%s\033[0m\n" "$*"; }
DONE_MSG=$(done_msg done)

DISTRIBUTION="$(lsb_release -i -s  | tr A-Z a-z)"
DISTVERSION="$(lsb_release -c -s)"

DIRECTORY=/home/mapit
RESOURCES_DIR=/home/resources
VENVS_DIR=/home/virtualenvs
WORKON_HOME=$VENVS_DIR

update_package_lists() {
    echo -n "Updating package lists... "
    sudo apt-get -qq update
    echo $DONE_MSG
}

check_distribution() {
    if [ x"$DISTRIBUTION" = x"ubuntu" ] && [ x"$DISTVERSION" = x"trusty" ]
    then
        : # Do nothing,
    else
        error_msg "Sorry, the only supported distribution is Ubuntu 14.04 (trusty)."
        exit 1
    fi

}

add_locale() {
    # Adds a specific UTF-8 locale (with Ubuntu you can provide it on the
    # command line, but Debian requires a file edit)

    echo -n "Generating locale $1... "
    if [ "$(locale -a | egrep -i "^$1.utf-?8$" | wc -l)" = "1" ]
    then
        notice_msg already
    else
        if [ x"$DISTRIBUTION" = x"ubuntu" ]; then
            locale-gen "$1.UTF-8"
        elif [ x"$DISTRIBUTION" = x"debian" ]; then
            if [ x"$(grep -c "^$1.UTF-8 UTF-8" /etc/locale.gen)" = x1 ]
            then
                notice_msg generating...
            else
                notice_msg adding and generating...
                echo "\n$1.UTF-8 UTF-8" >> /etc/locale.gen
            fi
            locale-gen
        fi
    fi
    echo $DONE_MSG
}


generate_locales() {
    echo "Generating locales... "
    # If language-pack-en is present, install that:
    sudo apt-get  install -y language-pack-en >/dev/null || true
    add_locale en_GB
    echo $DONE_MSG
}

set_locale() {
    echo 'LANG="en_GB.UTF-8"' > locale
    echo 'LC_ALL="en_GB.UTF-8"' >> locale
    sudo mv locale /etc/default/locale
    export LANG="en_GB.UTF-8"
    export LC_ALL="en_GB.UTF-8"
}

install_comfy_packages() {
    echo -n "Installing packages to have a comfortable work environment (vim, tmux, ...) "
    sudo apt-get install -qq -y vim tmux >/dev/null
    echo $DONE_MSG
}

install_nginx() {
    echo -n "Installing nginx... "
    sudo apt-get install -qq -y nginx-common nginx-full >/dev/null
    echo $DONE_MSG
}

install_postgis() {
    echo -n "Installing postgis, and other gis-related libraries... "
    sudo apt-get install -qq -y postgresql-9.3-postgis-2.1 postgresql-server-dev-9.3 >/dev/null
    sudo apt-get install -qq -y binutils libproj-dev gdal-bin >/dev/null
    echo $DONE_MSG
}

install_python27() {
    echo -n "Installing python, release 2.7 and pip"
    sudo apt-get install -qq -y python2.7 python2.7-dev python2.7-doc > /dev/null
    sudo apt-get install -qq -y python-pip >/dev/null
    echo $DONE_MSG
}

install_virtualenv() {
    if ! pip list | grep "virtualenv" >/dev/null
    then
        echo -n "Installing virtualenv and virtualenvwrapper"
        sudo mkdir -p $VENVS_DIR
        sudo chown vagrant.vagrant $VENVS_DIR
        sudo pip install virtualenv virtualenvwrapper >/dev/null
    else
        echo -n "virtualenv and virtualenvwrapper already installed"
    fi
    echo $DONE_MSG

    if ! egrep "WORKON_HOME" ".bashrc"
    then
        echo -n "Patching .bashrc to configure virtualenvwrapper"
        cat >> .bashrc << EOF
export WORKON_HOME=$VENVS_DIR

source /usr/local/bin/virtualenvwrapper.sh
alias pm='python manage.py'
alias py='python'
EOF
    fi
    echo -n "Reading virtualenvwrapper definitions"
    source /usr/local/bin/virtualenvwrapper.sh
    echo $DONE_MSG
}


install_uwsgi() {
    echo -n "Installing uwsgi"
    sudo pip install uwsgi >/dev/null
    echo $DONE_MSG

    # add uwsgi to upstart
    if ! egrep "uwsgi" "/etc/init"
    then
        echo -n "Adding uwsgi to upstart"
        cat > uwsgi.conf << EOF
# uWSGI Emperor

description "uwsgi emperor"
start on runlevel [2345]
stop on runlevel [06]

exec /usr/local/bin/uwsgi --emperor /etc/uwsgi/vassals --uid www-data --gid www-data --daemonize=/var/log/uwsgi/emperor.log
EOF
        sudo mv uwsgi.conf /etc/init
        echo $DONE_MSG
    fi
}

start_uwsgi() {
    echo -n "Starting uwsgi for the first time"
    sudo mkdir -p /etc/uwsgi/vassals >/dev/null
    sudo mkdir -p /var/log/uwsgi/ >/dev/null
    sudo chown www-data /var/log/uwsgi >/dev/null

    # first uwsgi start
    sudo /usr/local/bin/uwsgi --emperor /etc/uwsgi/vassals --uid www-data --gid www-data --daemonize=/var/log/uwsgi/emperor.log >/dev/null
    echo $DONE_MSG
}

configure_postgres() {
    echo -n "Configuring non-pwd access for postgresql"
    sudo chmod -R g+w /etc/postgresql/9.3/main
    sudo chgrp -R root /etc/postgresql/9.3/main
    sudo cat > pg_hba.conf << EOF
# Database administrative login by Unix domain socket
local   all             postgres                                trust

# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
# IPv6 local connections:
host    all             all             ::1/128                 trust
EOF
    sudo mv pg_hba.conf /etc/postgresql/9.3/main/
    sudo chmod -R g-w /etc/postgresql/9.3/main
    sudo chown -R postgres /etc/postgresql/9.3/main
    sudo service postgresql restart
    echo $DONE_MSG
}

create_database() {
    echo -n "Creating database"
    createdb -Upostgres mapit
    psql -Upostgres mapit -c "CREATE EXTENSION postgis;"
    psql -Upostgres mapit -c "CREATE EXTENSION postgis_topology;"
    echo $DONE_MSG
}

create_resources_path() {
    echo -n "Creating resources path"
    pushd $DIRECTORY >/dev/null
    sudo mkdir -p $RESOURCES_DIR/mapit
    sudo chown vagrant:vagrant $RESOURCES_DIR/mapit
    mkdir -p $RESOURCES_DIR/mapit/media >/dev/null
    mkdir -p $RESOURCES_DIR/mapit/static >/dev/null
    mkdir -p $RESOURCES_DIR/mapit/run >/dev/null
    mkdir -p $RESOURCES_DIR/mapit/logs/nginx >/dev/null
    sudo chown www-data -R $RESOURCES_DIR/mapit/logs $RESOURCES_DIR/mapit/run $RESOURCES_DIR/mapit/media >/dev/null
    popd >/dev/null
    echo $DONE_MSG
}


install_sass_ruby() {
    echo -n "Installing ruby and sass"
    sudo apt-get -qq -y install ruby-full >/dev/null
    sudo gem install sass >/dev/null
    echo $DONE_MSG
}


configure_uwsgi() {
    echo -n "Configure uwsgi"
    pushd $DIRECTORY >/dev/null
    cat > conf/uwsgi.ini << EOF
# configuration file for uwsgi
#
# link this as django.ini into the /etc/uwsgi/vassals dir
#
[uwsgi]
vacuum = true
master = true
processes = 3
daemonize = $RESOURCES_DIR/mapit/logs/uwsgi.log
harakiri = 15
harakiri-verbose = true
post-buffering = true

show-config = true

# set the http port
socket = $RESOURCES_DIR/mapit/run/socket
chown-socket = www-data:www-data

# change to django project directory
chdir = $DIRECTORY
home = $VENVS_DIR/mapit

# load django
module = project.wsgi
EOF
    if [ ! -f /etc/uwsgi/vassals/mapit.ini ]
    then
        sudo ln -s $DIRECTORY/conf/uwsgi.ini /etc/uwsgi/vassals/mapit.ini
    fi
    popd >/dev/null
    echo $DONE_MSG
}

configure_nginx() {
    echo -n "Configure nginx"
    pushd $DIRECTORY >/dev/null
    cat > conf/nginx.conf<< EOF
upstream mapit {
    server unix:///$RESOURCES_DIR/mapit/run/socket;
}

server {
        listen    80;

        server_name localhost;

        charset utf-8;
        client_max_body_size 75m;

        error_page 502 503 /static/503.html;

        access_log $RESOURCES_DIR/mapit/logs/nginx/access.log;
        error_log $RESOURCES_DIR/mapit/logs/nginx/error.log;

        location /static {
            alias $RESOURCES_DIR/mapit/static;
        }

        location /media {
            alias $RESOURCES_DIR/mapit/media;
        }

        location / {
            uwsgi_pass mapit;
            include /etc/nginx/uwsgi_params;
        }
}
EOF
    popd >/dev/null
    echo -n "Restarting nginx"
    sudo rm -f /etc/nginx/sites-enabled/*
    sudo ln -s $DIRECTORY/conf/nginx.conf /etc/nginx/sites-enabled/mapit >/dev/null
    sudo service nginx restart >/dev/null
    echo $DONE_MSG
}


# functions invocation

check_distribution
update_package_lists

generate_locales
set_locale

install_comfy_packages

install_nginx
install_postgis

install_sass_ruby
install_python27

install_virtualenv

install_uwsgi
create_resources_path

configure_postgres
if ! psql -Upostgres -l | grep mapit
then
    create_database
fi

start_uwsgi
configure_uwsgi
configure_nginx

