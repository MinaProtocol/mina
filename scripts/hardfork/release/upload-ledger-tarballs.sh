#!/usr/bin/env bash

# upload_ledger_tarballs.sh
# -------------------------
# This script uploads ledger tarball files from a specified folder to an AWS S3 bucket (snark-keys.o1test.net).
#
# For each file in the input folder:
#   - If the file already exists in the S3 bucket, it downloads the existing file, computes its hash,
#     and updates 'new_config.json' with the new hash.
#   - If the file does not exist in the bucket, it uploads the file with public-read ACL.
#
# Usage:
#   ./upload_ledger_tarballs.sh [input_folder]
#   input_folder: Folder containing ledger tarballs (default: hardfork_ledgers)
#
# Parallelization:
#   Uses GNU parallel via xargs to process files concurrently (8 at a time).
#
# Notes:
#   - Requires AWS CLI and OpenSSL.
#   - Handles only regular files in the input folder.
#   - Designed for use in CI or manual upload workflows.

set -euox pipefail

INPUT_FOLDER=${1:-hardfork_ledgers}  # Folder to scan for ledger tarballs
NEW_CONFIG=${2:-new_config.json}  # Path to the new_config.json file to update with new hashes
LEDGER_S3_BUCKET=${LEDGER_S3_BUCKET:-"s3://snark-keys.o1test.net"}

check_aws_cli() {
  echo "--- Checking for AWS CLI installation"
  if ! command -v aws &> /dev/null; then
    echo "❌ Error: AWS CLI is not installed. Please install it first."
    echo "You can install it using:"
    echo "  - curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip\" -o \"awscliv2.zip\""
    echo "  - unzip awscliv2.zip"
    echo "  - sudo ./aws/install"
    exit 1
  fi
  echo "✅ AWS CLI is available"
}

check_s3_permissions() {
  echo "--- Checking AWS S3 permissions for bucket access"
  if ! aws s3 ls "$LEDGER_S3_BUCKET" > /dev/null 2>&1; then
    echo "❌ Error: Unable to access S3 bucket '$LEDGER_S3_BUCKET'"
    echo "Please check your AWS credentials and permissions."
    exit 1
  fi
  echo "✅ S3 bucket access verified"
}

check_aws_cli
check_s3_permissions

# Get list of existing files in the S3 bucket
existing_files=$(aws s3 ls "$LEDGER_S3_BUCKET" | awk '{print $4}')

for file in "$INPUT_FOLDER"/*; do
  filename=$(basename "$file")
  printf "Processing: %s\n" "$filename"
  if echo "$existing_files" | grep -q "$filename"; then
    printf "Info: %s already exists in the bucket, packaging it instead.\n" "$filename"
    printf "Computing old hash for %s...\n" "$filename"
    oldhash=$(openssl dgst -r -sha3-256 "$file" | awk '{print $1}')
    printf "Downloading %s from S3...\n" "$filename"
    aws s3 cp "$LEDGER_S3_BUCKET/$filename" "$file"
    printf "Computing new hash for %s...\n" "$filename"
    newhash=$(openssl dgst -r -sha3-256 "$file" | awk '{print $1}')
    printf "Updating hash in %s for %s...\n" "$NEW_CONFIG" "$filename"
    sed -i "s/$oldhash/$newhash/g" "$NEW_CONFIG"
    printf "Done updating %s.\n" "$filename"
  else
    printf "Uploading %s to S3...\n" "$filename"
    aws s3 cp --acl public-read "$file" "$LEDGER_S3_BUCKET/"
    printf "Done  uploading %s.\n" "$filename"
  fi
done