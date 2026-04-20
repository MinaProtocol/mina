#!/bin/sh
# Configure APT caching proxy with runtime fallback for the Mina debian package repository.
#
# Usage: configure-apt-proxy.sh [APT_CACHE_URL] [DEB_REPO]
#   APT_CACHE_URL  - URL of the apt-cacher-ng or similar caching proxy (e.g. http://apt-cache:3142)
#   DEB_REPO       - URL of the Mina deb repo that must bypass the proxy (e.g. http://packages.o1test.net)
#
# If APT_CACHE_URL is empty the script exits cleanly without writing anything,
# so it is always safe to call unconditionally.
#
# Instead of hardcoding a static proxy, this script installs a Proxy-Auto-Detect
# script that probes the proxy at runtime. If the proxy is unreachable (e.g. the
# image runs outside the build cluster), APT falls back to direct upstream access.
#
# This script can be used both:
#  - Inside Dockerfiles (via COPY + RUN)
#  - Directly in CI shell scripts when apt is invoked on the agent host

set -eu

APT_CACHE_URL="${1:-}"
DEB_REPO="${2:-}"

# Nothing to configure when no proxy is requested.
[ -n "$APT_CACHE_URL" ] || exit 0

# --- Write the auto-detect probe script ---
probe=/usr/local/bin/apt-proxy-detect.sh
cat > "$probe" <<PROBE_EOF
#!/bin/sh
# Auto-detect APT proxy: use the cache if reachable, otherwise go DIRECT.
if curl --connect-timeout 2 -sf "${APT_CACHE_URL}/acng-report.html" >/dev/null 2>&1; then
  echo "${APT_CACHE_URL}"
else
  echo "DIRECT"
fi
PROBE_EOF
chmod +x "$probe"

# --- Write APT config that delegates to the probe ---
conf=/etc/apt/apt.conf.d/01proxy
{
  echo "Acquire::http::Proxy-Auto-Detect \"${probe}\";"
  echo "Acquire::https::Proxy-Auto-Detect \"${probe}\";"
  if [ -n "$DEB_REPO" ]; then
    host="${DEB_REPO#*://}"
    host="${host%%[:/]*}"
    echo "Acquire::http::Proxy::${host} \"DIRECT\";"
    echo "Acquire::https::Proxy::${host} \"DIRECT\";"
  fi
} > "$conf"

echo "--- APT proxy config (auto-detect) ---"
cat "$conf"
echo "--- Probe script ---"
cat "$probe"
echo "--------------------"
