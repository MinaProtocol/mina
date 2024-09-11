 #!/bin/bash

set -euo pipefail

user=$1
password=$2
db=$3


sudo service postgresql start
sudo -u postgres psql -c "CREATE USER ${user} WITH LOGIN SUPERUSER PASSWORD '${password}';"
sudo pg_isready
service postgresql status
sudo -u postgres createdb -O $user $db
PGPASSWORD=$password psql -h localhost -p 5434 -U $user -d $db -a -f src/app/archive/create_schema.sql
