#!/bin/bash

POSTGRES_DATA_DIR=${1:=/data/postgresql}
POSTGRES_DBNAME=${2:=archive}

mkdir -p ${POSTGRES_DATA_DIR} \
chown postgres ${POSTGRES_DATA_DIR}

POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')
echo "Initializing postgresql version $POSTGRES_VERSION" "$(psql -V)"
pg_dropcluster --stop ${POSTGRES_VERSION} main 
pg_createcluster --start ${POSTGRES_VERSION} -d ${POSTGRES_DATA_DIR} main
echo "data_directory = '/data/postgresql'" >> /etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf
echo "listen_addresses='*'" >> /etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf
echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf
/etc/init.d/postgresql start
psql --command "CREATE USER pguser WITH SUPERUSER PASSWORD 'pguser';"
sudo -u postgres createdb -O pguser ${POSTGRES_DBNAME}

# Leave database uninitialized so that rosetta scripts can start from scretch
# psql postgresql://pguser:pguser@localhost:5432/archive -f /archive/create_schema.sql

