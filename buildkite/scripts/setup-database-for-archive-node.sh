#!/bin/bash

set -euox pipefail

user=$1
password=$2
db=$3


sudo service postgresql start
sudo -u postgres psql -c "CREATE USER ${user} WITH LOGIN SUPERUSER PASSWORD '${password}';"
sudo pg_isready
service postgresql status
sudo -u postgres createdb -O "${user}" "${db}"

# detects up a PostgreSQL database for an archive node.
# Postgresql Environment Variables
PGVERSION=$(pg_lsclusters | awk 'NR==2 {print $1}')

if [[ -z "$PGVERSION" ]]; then
    echo "Error: PostgreSQL version not found"
    exit 1
fi

PGPORT_DEFAULT="${PGPORT:-5432}"

psql_config_file="/etc/postgresql/${PGVERSION}/main/postgresql.conf"
if [[ ! -f "$psql_config_file" ]]; then
    echo "Error: PostgreSQL configuration file not found"
    echo "Using PGPORT_DEFAULT: ${PGPORT_DEFAULT}"
    PGPORT="${PGPORT_DEFAULT}"
else
    PGPORT=$(grep -Po 'port = \K.*' "/etc/postgresql/${PGVERSION}/main/postgresql.conf" | awk -F" " '{print $1F}' || echo "error")
    if [[ $PGPORT == 'error' ]]; then
        echo "Error: Failed to retrieve PGPORT"
        echo "Using PGPORT_DEFAULT: ${PGPORT_DEFAULT}"
        PGPORT="${PGPORT_DEFAULT}"
    fi
fi

PGPASSWORD="${password}" psql -h localhost -p "${PGPORT}" -U "${user}" -d "${db}" -a -f src/app/archive/create_schema.sql

MINA_TEST_POSTGRES="postgres://${user}:${password}@localhost:${PGPORT}/${db}"

export MINA_TEST_POSTGRES
export PGPORT
