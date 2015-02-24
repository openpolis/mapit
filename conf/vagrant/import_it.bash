#!/usr/bin/env bash

# abort on any errors
set -e

# check that we are in the expected directory
cd "$(dirname $BASH_SOURCE)"/..

resources_dir=/home/resources/mapit
app_dir=/home/mapit

virtualenvs_dir='/home/virtualenvs'
virtualenv_dir="$virtualenvs_dir/mapit"
virtualenv_activate="$virtualenv_dir/bin/activate"


# download italian boundaries file
cd $resources_dir
#curl -L -s -O http://www.istat.it/storage/basi_territoriali_2013/LimAmm2011_WGS84.zip
#unzip LimAmm2011_WGS84.zip

source $virtualenv_activate
cd $app_dir

# create generation
python manage.py mapit_generation_create --desc="Initial import" --commit

# import Regioni
python manage.py mapit_import --generation_id 1 \
    --country_code I --country_name "Italia" \
    --area_type_code REG --area_type_descr "Regione"\
    --name_type_code ISTAT_REG --name_type_descr "Denominazione ISTAT per le Regioni"\
    --code_type ISTAT_REG --code_type_descr "Codice ISTAT per le Regioni"\
    --name_field NOME --code_field COD_REG \
    --encoding "ISO-8859-1" \
    --commit $resources_dir/LimAmm2011_WGS84/Reg2011_WGS84/Reg2011_WGS84.shp

# import Provincie
python manage.py mapit_import --country_code I --generation_id 1 \
    --area_type_code PRO --area_type_descr "Provincia"\
    --name_type_code ISTAT_PRO --name_type_descr "Denominazione ISTAT per le Province"\
    --code_type ISTAT_PRO --code_type_descr "Codice ISTAT per le Province"\
    --name_field NOME --code_field COD_PRO \
    --encoding "ISO-8859-1" \
    --commit $resources_dir/LimAmm2011_WGS84/Prov2011_WGS84/Prov2011_WGS84.shp

# import Comuni
python manage.py mapit_import --country_code I --generation_id 1 \
    --area_type_code COM --area_type_descr "Comuni"\
    --name_type_code ISTAT_COM --name_type_descr "Denominazione ISTAT per i Comuni"\
    --code_type ISTAT_COM --code_type_descr "Codice ISTAT per i Comuni"\
    --name_field NOME --code_field COD_ISTAT \
    --encoding "ISO-8859-1" \
    --commit $resources_dir/LimAmm2011_WGS84/Com2011_WGS84/Com2011_WGS84.shp


