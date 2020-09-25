#!/bin/bash

set -eou pipefail

echo "--- generate change DIFF"
diff=$(
  ./buildkite/scripts/generate-diff.sh
)

echo "--- identify modifications to helm charts (based on existence of Chart.yaml at change root)"
charts=$(
  for val in $diff; do
    find $(dirname $val) -name 'Chart.yaml';
  done
)

echo "--- filter duplicate Helm repos" 
dirs=$(dirname $charts | xargs -n1 | sort -u | xargs)

syncDir="sync_dir"
mkdir -p $syncDir

echo "--- Syncing with remote GCS Helm chart repository"
gsutil -m rsync ${CODA_CHART_REPO:-"gs://coda-charts/"} $syncDir

echo "--- Preparing the following charts for Release: ${charts}"
for dir in $dirs; do
  echo "--- Checking for Chart version bump: ${dir}/Chart.yaml"
  git diff develop... "${dir}/Chart.yaml" | grep version

  echo "--- Creating updated chart package: ${dir}/Chart.yaml"
  helm package $dir --destination $syncDir
done

echo "--- Generating index based on chart updates"
helm repo index $syncDir

if [ -n "${AUTO_DEPLOY+x}" ]; then
    echo "--- Deploying/Syncing with remote repository"
    gsutil -m rsync $syncDir ${CODA_CHART_REPO:-"gs://coda-charts/"}
fi

