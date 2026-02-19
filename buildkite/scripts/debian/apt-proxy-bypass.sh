#!/bin/sh
# Generate apt-get proxy bypass options for a given host.
#
# Usage: eval "$(./buildkite/scripts/debian/apt-proxy-bypass.sh [HOST])"
#   Then use $APT_PROXY_BYPASS_OPTS in apt-get commands.
#
# Arguments:
#   HOST - hostname to bypass (default: localhost)

APT_PROXY_BYPASS_HOST="${1:-localhost}"
APT_PROXY_BYPASS_OPTS="-o Acquire::http::Proxy::${APT_PROXY_BYPASS_HOST}=DIRECT -o Acquire::https::Proxy::${APT_PROXY_BYPASS_HOST}=DIRECT"
