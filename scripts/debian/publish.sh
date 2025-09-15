#!/bin/bash
set -eo pipefail

CLEAR='\033[0m'
RED='\033[0;31m'

ARCH=amd64
BUCKET=packages.o1test.net

# Forcing upload debian even if it exists already
FORCE=0

while [[ "$#" -gt 0 ]]; do case $1 in
  -n|--names) DEB_NAMES="$2"; shift;;
  -r|--release) DEB_RELEASE="$2"; shift;;
  -v|--version) DEB_VERSION="$2"; shift;;
  -c|--codename) DEB_CODENAME="$2"; shift;;
  -b|--bucket) BUCKET="$2"; shift;;
  -f|--force) FORCE=1;;
  -s|--sign) SIGN="$2"; shift;;
  *) echo "❌  Unknown parameter passed: $1"; exit 1;;
esac; shift; done

function usage() {
  if [[ -n "$1" ]]; then
    echo -e "${RED}☞  $1${CLEAR}\n";
  fi
  echo "Usage: $0 -n names -r release -v version -c codename"
  echo "  -n, --names         The Debians archive names"
  echo "  -r, --release       The Debian release"
  echo "  -b, --bucket        The Bucket which holds debian repo"
  echo "  -v, --version       The Debian version"
  echo "  -c, --codename      The Debian codename"
  echo "  -s, --sign          The Debian key id used for sign"
  echo ""
  echo "Example: $0 --name mina-archive --release unstable --version 2.0.0-rc1-48efea4 --codename bullseye "
  exit 1
}

# Invalidate CloudFront cache for the given bucket or CNAME and paths
# This is to ensure that after uploading new debs, users don't get stale
# package lists from CloudFront cache
# Usage: invalidate_cache [bucket-or-cname] codename
# Example: invalidate_cache nightly.apt.packages.minaprotocol.com bookworm
function invalidate_cache() {
  BUCKET_OR_CNAME="${1:-nightly.apt.packages.minaprotocol.com}"
  PATHS_TO_INVALIDATE="/dists/$2/*"

  echo "🔎 Resolving ${BUCKET_OR_CNAME}..."
  CF_DOMAIN=$(dig +short CNAME "${BUCKET_OR_CNAME}" | sed 's/\.$//')
  CF_DOMAIN=$(dig +short CNAME "${BUCKET_OR_CNAME}" | sed 's/\.$//')

  if [[ -z "$CF_DOMAIN" ]]; then
    echo "❌ Could not resolve ${BUCKET_OR_CNAME} to a CloudFront domain."
    exit 1
  fi

  echo "✅ Found CloudFront domain: ${CF_DOMAIN}"

  echo "📋 Searching for distribution ID in CloudFront..."
  DIST_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?DomainName=='${CF_DOMAIN}'].Id" \
    --output text)

  if [[ -z "$DIST_ID" ]]; then
    echo "❌ No CloudFront distribution found for domain ${CF_DOMAIN}"
    exit 1
  fi

  echo "✅ Found CloudFront distribution ID: ${DIST_ID}"

  echo "🚀 Creating invalidation for paths: ${PATHS_TO_INVALIDATE}"
  aws cloudfront create-invalidation \
    --distribution-id "${DIST_ID}" \
    --paths "${PATHS_TO_INVALIDATE}"
}


if [[ -z "$DEB_NAMES" ]]; then usage "❌  Debian(s) to upload are not set!"; fi;
if [[ -z "$DEB_VERSION" ]]; then usage "❌  Version is not set!"; fi;
if [[ -z "$DEB_CODENAME" ]]; then usage "❌  Codename is not set!"; fi;
if [[ -z "$DEB_RELEASE" ]]; then usage "❌  Release is not set!"; fi;


if [[ -z "${SIGN:-}" ]]; then 
  SIGN_ARG=""
else
  SIGN_ARG="--sign=$SIGN"
fi

BUCKET_ARG="--bucket=$BUCKET"
S3_REGION_ARG="--s3-region=us-west-2"

if [[ -z "${PASSPHRASE:-}" ]]; then
  GPG_OPTS=()
else
  GPG_OPTS=("--gpg-options=\"--batch" "--pinentry-mode=loopback" "--yes")
fi

echo "Publishing debs: ${DEB_NAMES} to Release: ${DEB_RELEASE} and Codename: ${DEB_CODENAME}"
# Upload the deb files to s3.
# If this fails, attempt to remove the lockfile and retry.
for _ in {1..10}; do (
  # utility for publishing deb repo with commons options
# deb-s3 https://github.com/krobertson/deb-s3
#NOTE: Do not remove --lock flag otherwise racing deb uploads may overwrite the registry and some files will be lost. If a build fails with the following error, delete the lock file https://packages.o1test.net/dists/unstable/main/binary-/lockfile and rebuild
#>> Checking for existing lock file
#>> Repository is locked by another user:  at host dc7eaad3c537
#>> Attempting to obtain a lock
#/var/lib/gems/2.3.0/gems/deb-s3-0.10.0/lib/deb/s3/lock.rb:24:in `throw': uncaught throw #"Unable to obtain a lock after 60, giving up."
deb-s3 upload $BUCKET_ARG $S3_REGION_ARG \
  "$([ "$FORCE" -eq 0 ] && echo "--fail-if-exists")" \
  --lock \
  --preserve-versions \
  --cache-control "no-store,no-cache,must-revalidate" \
  $SIGN_ARG \
  --component "${DEB_RELEASE}" \
  --codename "${DEB_CODENAME}" \
  "${GPG_OPTS[@]}" \
  "${DEB_NAMES}"
) && break || (MINA_DEB_BUCKET=${BUCKET} scripts/debian/clear-s3-lockfile.sh); done

invalidate_cache "$BUCKET" "$DEB_CODENAME"

for deb in $DEB_NAMES
do
  # extracting name from debian package path. E.g:
  # _build/mina-archive_3.0.1-develop-a2a872a.deb -> mina-archive
  deb=$(basename "$deb")
  deb="${deb%_*}"
  debs+=("$deb")
done

function join_by { local IFS="$1"; shift; echo "$*"; }

tries=10
counter=0

while (( ${#debs[@]} ))
do
  join=$(join_by " " "${debs[@]}")

  IFS=$'\n'
  output=$(deb-s3 exist $BUCKET_ARG $S3_REGION_ARG "$join" $DEB_VERSION $ARCH -c $DEB_CODENAME -m $DEB_RELEASE)
  debs=()
  for item in $output; do
     if [[ $item == *"Missing" ]]; then
      key=$(echo "$item" | awk '{print $1}')
      debs+=("$key")
     fi
  done

  if [ ${#debs[@]} -eq 0 ]; then
    echo "✅  All debians are correctly published to our debian repository"

    if [[ $DEB_RELEASE == "unstable" ]]; then
      echo "⏩️  Skipping debian repository consistency check after push to unstable channel as it is taking too long."
    else 
      echo "📋  Validating debian repository consistency after push..."
      if deb-s3 verify  $BUCKET_ARG $S3_REGION_ARG -c $DEB_CODENAME -m $DEB_RELEASE; then 
        echo "✅  Debian repository is consistent"
      else
        echo "❌  Error: Debian repository is not consistent. Please run: "
        echo "💻  deb-s3 verify  $BUCKET_ARG $S3_REGION_ARG -c $DEB_CODENAME -m $DEB_RELEASE --fix-manifests"
        exit 1
      fi
    fi
    break
  fi

  counter=$((counter+1))
  if [[ $((counter)) == $((tries)) ]]; then
    # shellcheck disable=SC2046
    echo "❌  Error: Some Debians are still not correctly published : "$(join_by " " "${debs[@]}")
    echo "ℹ️  You may still try to rerun job as debian repository is known from imperfect performance"
    exit 1
  fi 

  sleep 60
done