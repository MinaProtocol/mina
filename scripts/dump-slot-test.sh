ARCHIVE_DIR=src/test/archive
DUMP_SLOT_APP=_build/default/src/app/dump_slot_ledger/dump_slot_ledger.exe
PG_CONN=postgres://postgres:postgres@localhost:5433/archive

while [[ "$#" -gt 0 ]]; do case $1 in
  -d|--dir) ARCHIVE_DIR="$2"; shift;;
  -a|--app) DUMP_SLOT_APP="$2"; shift;;
  -p| --pg) PG_CONN="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done


echo "Running slot dumping tool"
OUTPUT=$($DUMP_SLOT_APP --postgres-uri $PG_CONN --slot 60)

EXPECTED=""
echo $OUTPUT

if [ $OUTPUT == $EXPECTED ]; then
    exit 0
else
    exit 1
fi