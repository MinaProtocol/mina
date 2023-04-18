#!/bin/bash

set -eou pipefail

eval $(opam config env) && export PATH=$HOME/.cargo/bin:$PATH && ./scripts/heap_usage.sh
