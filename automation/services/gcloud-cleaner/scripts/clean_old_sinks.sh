#!/bin/bash

set -eo pipefail

DRYRUN="true"
PREDICATE_IN_DAYS=60

while [ $# -gt 0 ]; do
  case "$1" in
    --age=*)
      PREDICATE_IN_DAYS="${1#*=}"
      ;;
    --dryrun=*)
      DRYRUN="${1#*=}"
      ;;
  esac
  shift
done

# Set the project ID to search for log sinks
PROJECT_ID="o1labs-192920"

# Older than predicate
PREDICATE="$PREDICATE_IN_DAYS days ago"

# Get the list of all log sinks in the project
SINKS=$(gcloud logging sinks list --project=${PROJECT_ID} --format="value(name)")

TOTAL_COUNTER=0
DELETE_COUNTER=0
# Loop through all the log sinks and delete the ones that contain "it-auto" in their name and passes the predicate
echo "Cleaning in process (AGE=${PREDICATE}, DRYRUN=${DRYRUN}). It may take few minutes..."
for SINK in ${SINKS}; do
    TOTAL_COUNTER=$((TOTAL_COUNTER+1))
    if [[ ${SINK} == *"it-auto"* ]]; then
        date=$(gcloud logging sinks describe ${SINK} --format="value(createTime)")
        sixty_days_ago=$(date +%F -d "$PREDICATE")
    	  if [[ $date < $sixty_days_ago ]]; then 
	    	  DELETE_COUNTER=$((DELETE_COUNTER+1))
          if [[ ${DRYRUN} == "false" ]]; then
            echo "${SINK} was created more than $PREDICATE. deleting log sink ..."
            gcloud logging sinks delete ${SINK} --project=${PROJECT_ID} -q
          else 
            echo "[DRYRUN] ${SINK} was created more than $PREDICATE. It will be deleted on standard run"
          fi
	      fi
    fi
done

if [[ ${DRYRUN} -eq 1 ]]; then
    SUFFIX="will be deleted on standard run"
else 
    SUFFIX="deleted"
fi

echo "Cleaning complete. ${DELETE_COUNTER} out of ${TOTAL_COUNTER} sinks ${SUFFIX}."