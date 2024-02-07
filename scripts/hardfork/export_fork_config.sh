#!/bin/bash

set -beo pipefail
FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}
curl 'https://drive.usercontent.google.com/download?id=1JUQ9V6TnXOom-2j2q50oS60xOiv3mwtr&export=download&confirm=t' > $FORK_CONFIG_JSON
