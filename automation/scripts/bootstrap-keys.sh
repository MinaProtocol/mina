#!/bin/bash

# Function to display usage help
usage() {
    echo "Usage: $0 --testnet TESTNET_NAME"
    exit 1
}

# Parsing command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --testnet) TESTNET_NAME="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; usage; exit 1 ;;
    esac
    shift
done

# Check if testnet name is provided
if [ -z "$TESTNET_NAME" ]; then
    echo "Error: Testnet name not provided."
    usage
    exit 1
fi

# Source keys directory
BASEDIR="./terraform/testnets"
SRC_DIR="$BASEDIR/$TESTNET_NAME/keys"

# Target directory
TARGET_DIR="../helm/bootstrap/keys/"

# Check if source directory exists
if [ ! -d "$SRC_DIR" ]; then
    echo "Error: Source directory $SRC_DIR does not exist."
    exit 1
fi

# Copying files from source to target directory
cp -r "$SRC_DIR/"* "$TARGET_DIR/"

echo "Key files copied successfully from $SRC_DIR to $TARGET_DIR."

# Copying GCloud keyfile
KEYFILE="$BASEDIR/$TESTNET_NAME/gcloud-keyfile.json"

# Check if file exists
if [ -f "$KEYFILE" ]; then
    cp "$KEYFILE" "$TARGET_DIR/"
    echo "gcloud-keyfile.json copied successfully from $KEYFILE to $TARGET_DIR."
else
    echo "Error: gcloud-keyfile.json does not exist in $KEYFILE_SRC_DIR."
fi