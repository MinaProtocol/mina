#!/bin/sh
# Configure APT caching proxy with a bypass for the Mina debian package repository.
#
# Usage: configure-apt-proxy.sh [APT_CACHE_URL] [DEB_REPO]
#   APT_CACHE_URL  - URL of the apt-cacher-ng or similar caching proxy (e.g. http://apt-cache:3142)
#   DEB_REPO       - URL of the Mina deb repo that must bypass the proxy (e.g. http://packages.o1test.net)
#
# If APT_CACHE_URL is empty the script exits cleanly without writing anything,
# so it is always safe to call unconditionally.
#
# This script can be used both:
#  - Inside Dockerfiles (via COPY + RUN)
#  - Directly in CI shell scripts when apt is invoked on the agent host

set -eu

APT_CACHE_URL="${1:-}"
DEB_REPO="${2:-}"

# Nothing to configure when no proxy is requested.
[ -n "$APT_CACHE_URL" ] || exit 0

conf=/etc/apt/apt.conf.d/01proxy
{
  echo "Acquire::http::Proxy \"${APT_CACHE_URL}\";"
  echo "Acquire::https::Proxy \"${APT_CACHE_URL}\";"
  if [ -n "$DEB_REPO" ]; then
    host="${DEB_REPO#*://}"
    host="${host%%[:/]*}"
    echo "Acquire::http::Proxy::${host} \"DIRECT\";"
    echo "Acquire::https::Proxy::${host} \"DIRECT\";"
  fi
} > "$conf"

echo "--- APT proxy config ---"
cat "$conf"
echo "------------------------"
