#!/bin/bash

POSTGRES_DATA_DIR=$1
POSTGRES_DBNAME=$2
POSTGRES_USERNAME=$3
POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')
PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}

pg_ctlcluster ${POSTGRES_VERSION} main start
psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
RETURN_CODE=$?
[[ "$RETURN_CODE" == "0" ]] && echo "[WARN] Database already initialized!" && exit ${RETURN_CODE}

mkdir -p ${POSTGRES_DATA_DIR}
chown postgres ${POSTGRES_DATA_DIR}

echo "Initializing postgresql version $POSTGRES_VERSION"
pg_dropcluster --stop ${POSTGRES_VERSION} main
pg_createcluster --start ${POSTGRES_VERSION} -d ${POSTGRES_DATA_DIR} main

sudo -u postgres echo "data_directory = '/data/postgresql'" >> /etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf
sudo -u postgres echo "listen_addresses='*'" >> /etc/postgresql/${POSTGRES_VERSION}/main/postgresql.conf
sudo -u postgres echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/${POSTGRES_VERSION}/main/pg_hba.conf

sudo -u postgres /etc/init.d/postgresql start

sudo -u postgres psql --command "CREATE USER ${POSTGRES_USERNAME} WITH SUPERUSER PASSWORD '${POSTGRES_USERNAME}';"
sudo -u postgres createdb -O ${POSTGRES_USERNAME} ${POSTGRES_DBNAME}

# Leave database uninitialized so that rosetta scripts can start from scretch
# psql postgresql://pguser:pguser@localhost:5432/archive -f /archive/create_schema.sql

