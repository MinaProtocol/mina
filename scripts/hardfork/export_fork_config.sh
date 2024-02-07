#!/bin/bash

set -beo pipefail
FORK_CONFIG_JSON=${FORK_CONFIG_JSON:=fork_config.json}
curl 'https://drive.usercontent.google.com/download?id=1iApqXo0vuBjitNkxVLlstJdwWf_zYzHl&export=download&confirm=t' > $FORK_CONFIG_JSON
