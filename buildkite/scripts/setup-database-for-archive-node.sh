 #!/bin/bash

user=$1
password=$2
db=$3

echo "WHICH SET: "
which set
echo

echo "BASH VERSION: "
bash --version
echo

set -euo pipefail

sudo apt-get install -y postgresql
sudo service postgresql start
sudo -u postgres psql -c "CREATE USER ${user} WITH SUPERUSER PASSWORD '${password}';"
sudo -u postgres createdb -O $user $db