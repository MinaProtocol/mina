#!/bin/bash

set -eou pipefail


diff=$(
  ./buildkite/scripts/generate-diff.sh
)
echo "--- Generated change DIFF: ${diff}"

# Identifying modifications to helm charts (based on existence of Chart.yaml at change root)
charts=$(
  for val in $diff; do
    find $(dirname ${val}) -name 'Chart.yaml' || true; # failures occur when value is undefined due to empty diff
  done
)

if [ -n "$charts" ]; then
  # filter duplicates
  charts=$(echo $charts | xargs -n1 | sort -u | xargs)
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

    gsutil -m rsync ${CODA_CHART_REPO:-"gs://coda-charts/"} $syncDir

    for dir in $dirs; do
      echo "--- Preparing chart for Release: ${dir}"
      helm package $dir --destination $stageDir

      if [ -n "${HELM_EXPERIMENTAL_OCI+x}" ]; then
        echo "--- Helm experimental OCI activated - deploying to GCR registry"
        helm chart save $(basename $dir)

        gcloud auth configure-docker
        docker login "gcr.io/o1labs-192920/coda-charts/$(basename ${dir})"

        helm chart push "gcr.io/o1labs-192920/coda-charts/$(basename ${dir})"
      fi
    done

    cp --force --recursive "${stageDir}" "${syncDir}"

    helm repo index $syncDir

    if [ -n "${AUTO_DEPLOY+x}" ]; then
        echo "--- Deploying/Syncing with remote repository"
        gsutil -m rsync $syncDir ${CODA_CHART_REPO:-"gs://coda-charts/"}
    fi
  fi
else
  echo "No Helm chart changes found in DIFF."
fi
