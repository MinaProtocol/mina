#!/bin/bash

set -euo pipefail

user=$1
password=$2
db=$3


sudo service postgresql start
sudo -u postgres psql -c "CREATE USER ${user} WITH LOGIN SUPERUSER PASSWORD '${password}';"
sudo pg_isready
service postgresql status
sudo -u postgres createdb -O "${user}" "${db}"

# detects up a PostgreSQL database for an archive node.
port=$(sudo -u postgres psql -t -c "SHOW port;" | xargs)
if [[ -z "$port" ]]; then
  echo "Failed to detect PostgreSQL port."
  exit 1
fi
  echo "$port"


PGPASSWORD="${password}" psql -h localhost -p "${port}" -U "${user}" -d "${db}" -a -f src/app/archive/create_schema.sql

export MINA_TEST_POSTGRES="postgres://${user}:${password}@localhost:${port}/${db}"