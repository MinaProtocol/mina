#!/bin/bash

set -eou pipefail


diff=$(
  ./buildkite/scripts/generate-diff.sh
)
echo "--- Generated change DIFF: ${diff}"

# Identify modifications to helm charts (based on existence of Chart.yaml at change root)
charts=$(
  for val in $diff; do
    find $(dirname ${val}) -name 'Chart.yaml' || true; # failures occur when value is undefined due to empty diff
  done
)

if [[ "$diff" =~ .*"helm-ci".* ]]; then
  echo "--- Change to Helm CI script found. Executing against ALL repo charts!"
  charts=$(find '.' -name 'Chart.yaml' || true)
fi

if [ -n "$charts" ]; then
  # filter duplicates
  charts=$(echo $charts | xargs -n1 | sort -u | xargs)
  dirs=$(dirname $charts | xargs -n1 | sort -u | xargs)

  if [ -n "${HELM_LINT+x}" ]; then
    for dir in $dirs; do
      if [[ "$dir" =~ .*"automation".* ]]; then
        # do not lint charts contained within the automation submodule
        continue
      fi

      echo "--- Linting: ${dir}"
      helm lint $dir

      echo "--- Executing dry-run: ${dir}"
      # Only attempt to execute DRY-RUNs against application charts
      chartType=$(cat $dir/Chart.yaml | grep 'type:' | awk '{ print $2}')
      if [[ "$chartType" =~ "application" ]]; then
        helm install test-archive-node $dir --dry-run --namespace test
      else
        echo "found library chart - skipping dry-run"
      fi
    done
  fi

  if [ -n "${HELM_RELEASE+x}" ]; then
    syncDir="sync_dir"
    stageDir="updates"
    mkdir -p $stageDir $syncDir

    gsutil -m rsync ${CODA_CHART_REPO:-"gs://coda-charts/"} $syncDir

    for dir in $dirs; do
      if [[ "$dir" =~ .*"automation".* ]]; then
        # do not release charts contained within the automation submodule
        continue
      fi

      echo "--- Preparing chart for Release: ${dir}"
      helm package $dir --destination $stageDir

      if [ -n "${HELM_EXPERIMENTAL_OCI+x}" ]; then
        echo "--- Helm experimental OCI activated - deploying to GCR registry"
        helm chart save "${dir}" "gcr.io/o1labs-192920/coda-charts/$(basename ${dir})"

        helm chart push "gcr.io/o1labs-192920/coda-charts/$(basename ${dir})"
      fi
    done

    echo "--- Syncing staging and release dirs"
    cp --force --recursive --verbose ${stageDir}/* ${syncDir}/

    helm repo index $syncDir

    if [ -n "${AUTO_DEPLOY+x}" ]; then
        echo "--- Deploying/Syncing with remote repository"
        gsutil -m rsync $syncDir ${CODA_CHART_REPO:-"gs://coda-charts/"}
    fi
  fi
else
  echo "No Helm chart changes found in DIFF."
fi
