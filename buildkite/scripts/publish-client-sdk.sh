#!/bin/bash

set -o pipefail

echo "--- (Pre)publish Client SDK"
source ~/.profile
cd frontend/client_sdk && yarn prepublishOnly
