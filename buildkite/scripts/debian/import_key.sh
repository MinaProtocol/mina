#!/bin/bash

set -eo pipefail

print_usage() {
  echo "Usage: $0 [-s|--silent] [-h|--help]"
}

SILENT=0
KEY_LOCATION="/var/secrets/debian/key.gpg"

while [[ "$#" -gt 0 ]]; do case $1 in
  -s|--silent) SILENT=1; ;;
  -h|--help) print_usage; exit 0;;
  *) echo "Unknown parameter passed: $1"; print_usage; exit 1;;
esac; shift; done

sudo chown -R opam ~/.gnupg/
if [ $SILENT == 1 ]; then
  gpg --batch --yes --import "$KEY_LOCATION"
else
  echo "Importing GPG key"
  gpg --import "$KEY_LOCATION"
 fi
