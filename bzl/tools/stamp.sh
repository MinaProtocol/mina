#!/bin/sh
set -e

branch=$(git rev-parse --verify --abbrev-ref HEAD || echo "<none found>")
commit_id_short=$(git rev-parse --short=8 --verify HEAD)

CWD=$PWD

if [ -n "$CODA_COMMIT_SHA1" ]; then
    # pull from env var if set
    id="$CODA_COMMIT_SHA1"
else
    if [ ! -e .git ]; then echo 'Error: git repository not found'; exit 1; fi
    id=$(git rev-parse --verify HEAD)
    if [ -n "$(git diff --stat)" ]; then id="[DIRTY]$id"; fi
fi
commit_date=$(git show HEAD -s --format="%cI")

cd src/lib/marlin
marlin_commit_id=$(git rev-parse --verify HEAD)
if [ -n "$(git diff --stat)" ]; then marlin_commit_id="[DIRTY]$id"; fi
marlin_commit_id_short=$(git rev-parse --short=8 --verify HEAD)
marlin_commit_date=$(git show HEAD -s --format="%cI")
cd ../../..

cd src/lib/zexe
zexe_commit_id=$(git rev-parse --verify HEAD)
if [ -n "$(git diff --stat)" ]; then zexe_commit_id="[DIRTY]$id"; fi
zexe_commit_id_short=$(git rev-parse --short=8 --verify HEAD)
zexe_commit_date=$(git show HEAD -s --format="%cI")
cd ../../..

echo "STABLE_MINA_COMMIT_ID $id"
echo "STABLE_MINA_COMMIT_ID_SHORT $commit_id_short"
echo "STABLE_MINA_BRANCH $branch"
echo "STABLE_MINA_COMMIT_DATE $commit_date"

echo "STABLE_MARLIN_COMMIT_ID $marlin_commit_id"
echo "STABLE_MARLIN_COMMIT_ID_SHORT $marlin_commit_id_short"
echo "STABLE_MARLIN_COMMIT_DATE $marlin_commit_date"

echo "STABLE_ZEXE_COMMIT_ID $zexe_commit_id"
echo "STABLE_ZEXE_COMMIT_ID_SHORT $zexe_commit_id_short"
echo "STABLE_ZEXE_COMMIT_DATE $zexe_commit_date"
