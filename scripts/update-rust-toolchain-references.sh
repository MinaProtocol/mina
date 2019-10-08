#!/bin/bash
set -e

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 newtag"
  exit
fi

filename="$SCRIPTPATH/../.circleci/config.yml.jinja"

echo "Updating $filename with new Rust toolchain reference: $1"
sed -i "s/toolchain-rust-[0-9a-f]\+/toolchain-rust-$1/g" $filename
