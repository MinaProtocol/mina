#!/bin/bash

set -eou pipefail

echo "--- Generating change DIFF"
diff=$(
  ./buildkite/scripts/generate-diff.sh
)

echo "--- Identifying modifications to helm charts (based on existence of Chart.yaml at change root)"
charts=$(
  for val in $diff; do
    find $(dirname $val) -name 'Chart.yaml';
  done
)
charts=$(echo $charts | xargs -n1 | sort -u | xargs)

echo "--- Filtering duplicate Helm repos" 
dirs=$(dirname $charts | xargs -n1 | sort -u | xargs)

if [ -n "${HELM_LINT+x}" ]; then
  for dir in $dirs; do
    echo "--- Linting: ${dir}"
    helm lint $dir

    echo "--- Executing dry-run: ${dir}"
    helm install test $dir --dry-run --namespace default
  done
fi

if [ -n "${HELM_RELEASE+x}" ]; then
  syncDir="sync_dir"
  stageDir="updates"
  mkdir -p $stageDir $syncDir

  echo "--- Syncing with remote GCS Helm chart repository"
  gsutil -m rsync ${CODA_CHART_REPO:-"gs://coda-charts/"} $syncDir

  echo "--- Preparing the following charts for Release: ${charts}"
  for dir in $dirs; do
    echo "--- Checking for Chart version bump: ${dir}/Chart.yaml"
    git diff develop... "${dir}/Chart.yaml" | grep version

    echo "--- Creating updated chart package: ${dir}/Chart.yaml"
    helm package $dir --destination $stageDir

    if [ -n "${HELM_EXPERIMENTAL_OCI+x}" ]; then
      echo "--- Helm experimental OCI activated - deploying to GCR registry"
      helm chart save $(basename $dir)

      gcloud auth configure-docker
      docker login "gcr.io/coda-charts/$(basename ${dir})"

      helm chart push "gcr.io/coda-charts/$(basename ${dir})"
    fi
  done

  echo "--- syncing staged chart updates"
  cp --force --recursive "${stageDir}" "${syncDir}"

  echo "--- Generating index based on chart updates"
  helm repo index $syncDir

  if [ -n "${AUTO_DEPLOY+x}" ]; then
      echo "--- Deploying/Syncing with remote repository"
      gsutil -m rsync $syncDir ${CODA_CHART_REPO:-"gs://coda-charts/"}
  fi
fi

