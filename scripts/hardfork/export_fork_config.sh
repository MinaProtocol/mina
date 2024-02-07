#!/bin/bash

set -beo pipefail

curl 'https://drive.usercontent.google.com/download?id=1r8BtQdp6QJz9WVevzBw8fn44EY5KQoNT&export=download&confirm=t' > $FORK_CONFIG_JSON
