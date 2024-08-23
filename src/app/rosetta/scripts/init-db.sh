#!/bin/bash

MINA_NETWORK=${1}
POSTGRES_DBNAME=$2
POSTGRES_USERNAME=$3
POSTGRES_DATA_DIR=$4
POSTGRES_VERSION=$(psql -V | cut -d " " -f 3 | sed 's/.[[:digit:]]*$//g')
PG_CONN=postgres://${POSTGRES_USERNAME}:${POSTGRES_USERNAME}@127.0.0.1:5432/${POSTGRES_DBNAME}
DUMP_TIME=${5:=0000}
MINA_ARCHIVE_DUMP_URL=${MINA_ARCHIVE_DUMP_URL:=https://storage.googleapis.com/mina-archive-dumps}
MINA_POSTGRES_CONF=${MINA_POSTGRES_CONF:=/etc/mina/rosetta/scripts/postgresql.conf}

pg_ctlcluster ${POSTGRES_VERSION} main start
echo "[POPULATE] Top 10 blocks in ${POSTGRES_DATA_DIR} archiveDB:"
sudo -u postgres psql "${POSTGRES_DBNAME}" --command "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
RETURN_CODE=$?
[[ "$RETURN_CODE" == "0" ]] && echo "[WARN] Database already initialized!" && exit ${RETURN_CODE}

echo "[POPULATE] Initializing postgresql version $POSTGRES_VERSION"
echo "[POPULATE] postgresql.conf:"
cat ${MINA_POSTGRES_CONF}

pg_dropcluster --stop ${POSTGRES_VERSION} main
pg_createcluster --start -d ${POSTGRES_DATA_DIR} --createclusterconf ${MINA_POSTGRES_CONF} ${POSTGRES_VERSION} main

sudo -u postgres psql --command "SHOW ALL;"

sudo -u postgres psql --command "CREATE USER ${POSTGRES_USERNAME} WITH SUPERUSER PASSWORD '${POSTGRES_USERNAME}';"
sudo -u postgres createdb -O ${POSTGRES_USERNAME} ${POSTGRES_DBNAME}

MAX_DAYS_LOOKBACK=5
TODAY=$(date)
i=0
while [ $i -lt $MAX_DAYS_LOOKBACK ]; do
    DATE=$(date -d "$TODAY- $i days" +%G-%m-%d)_${DUMP_TIME}
    STATUS_CODE=$(curl -s -o /dev/null --head -w "%{http_code}" "${MINA_ARCHIVE_DUMP_URL}/${MINA_NETWORK}-archive-dump-${DATE}.sql.tar.gz")
    if [[ ! $STATUS_CODE =~ 2[0-9]{2} ]]; then
        i=$((i + 1))
    else
        echo "Download ${MINA_NETWORK}-archive-dump-${DATE}"
        curl "${MINA_ARCHIVE_DUMP_URL}/${MINA_NETWORK}-archive-dump-${DATE}.sql.tar.gz" -o o1labs-archive-dump.tar.gz
        break
    fi
done

[[ $STATUS_CODE =~ 2[0-9]{2} ]] || echo "[WARN] Unable to find archive dump for ${MINA_NETWORK}"

tar -xvf o1labs-archive-dump.tar.gz
# It would help to know the block height of this dump in addition to the date
psql -f "${MINA_NETWORK}-archive-dump-${DATE}.sql" "${PG_CONN}"
rm -f o1labs-archive-dump.tar.gz

echo "[POPULATE] Top 10 blocks in populated archiveDB:"
psql "${PG_CONN}" -c "SELECT state_hash,height FROM blocks ORDER BY height DESC LIMIT 10"
