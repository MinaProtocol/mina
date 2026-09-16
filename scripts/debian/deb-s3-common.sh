#!/usr/bin/env bash
# Shared connection arguments for every deb-s3 call in the release tooling.
#
# deb-s3 talks to AWS S3 by default. Two optional environment variables redirect
# it at any S3-compatible server instead:
#
#   DEB_S3_ENDPOINT   full URL of the S3 API, e.g. http://127.0.0.1:9000
#   DEB_S3_REGION     region to claim (default: us-west-2)
#
# When DEB_S3_ENDPOINT is unset - which is the case for every production
# publish and promote - the arguments below are exactly what the tooling passed
# before, so live behaviour is unchanged.
#
# The release-manager test suite sets DEB_S3_ENDPOINT to a throwaway MinIO
# container. That is what lets those tests run with no AWS credentials and no
# live bucket. See buildkite/scripts/tests/release-manager/mock-repo.sh.
#
# --force-path-style is required with MinIO: deb-s3 otherwise addresses the
# bucket as a subdomain (bucket.host), which only AWS resolves.

# Both variables are read by the scripts that source this file, so shellcheck
# cannot see their use from here.
# shellcheck disable=SC2034
DEB_S3_REGION_ARG="--s3-region=${DEB_S3_REGION:-us-west-2}"

# An array, not a string. scripts/debian/publish.sh sets IFS=$'\n' around its
# deb-s3 calls so that it can iterate over the output line by line, and a
# space-separated string would then reach deb-s3 as a single argument
# ("--endpoint=http://host:9000 --force-path-style"). Array expansion ignores
# IFS, so it is correct wherever these arguments are used.
# shellcheck disable=SC2034
DEB_S3_ENDPOINT_ARGS=()
if [[ -n "${DEB_S3_ENDPOINT:-}" ]]; then
  # shellcheck disable=SC2034
  DEB_S3_ENDPOINT_ARGS=("--endpoint=${DEB_S3_ENDPOINT}" "--force-path-style")
fi

# Build the plain HTTP(S) URL of a single object, for readers that bypass deb-s3
# (wget, apt). Honours DEB_S3_ENDPOINT so that a mocked repository is readable
# by the same code path as the real one.
#
# Usage: deb_s3_object_url <bucket> <key>
function deb_s3_object_url() {
  local __bucket=$1
  local __key=$2

  if [[ -n "${DEB_S3_ENDPOINT:-}" ]]; then
    echo "${DEB_S3_ENDPOINT%/}/${__bucket}/${__key}"
  else
    echo "https://s3.${DEB_S3_REGION:-us-west-2}.amazonaws.com/${__bucket}/${__key}"
  fi
}
