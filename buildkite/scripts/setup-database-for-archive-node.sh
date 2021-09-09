 #!/bin/bash

set -euo pipefail

user=$1
password=$2
db=$3

sudo apt-get update -y && sudo apt-get install -y postgresql
sudo service postgresql start
sudo -u postgres psql -c "CREATE USER ${user} WITH SUPERUSER PASSWORD '${password}';"
sudo -u postgres createdb -O $user $db
