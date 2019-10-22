set -e

/bin/sh $CODA_DIRECTORY_PATH/scripts/archive/make_hasura_configurations.sh
/bin/sh $CODA_DIRECTORY_PATH/scripts/archive/check_hasura_configurations.sh
