#!/bin/bash

set -eou pipefail

echo "--- generate change DIFF"
diff=$(
  ./buildkite/scripts/generate-diff.sh
)
echo $diff

echo "--- identify modifications to helm charts (based on existence of Chart.yaml at change root)"
charts=$(
  for val in $diff; do
    find $(dirname $val) -name 'Chart.yaml';
  done
)

echo "--- filter duplicate Helm repos" 
dirs=$(dirname $charts | xargs -n1 | sort -u | xargs)

echo "--- Linting: ${dirs}"
for dir in $dirs; do
  helm lint $dir

  echo "--- Executing dry-run: ${dir}"
  helm install test $dir --dry-run --namespace default
done
