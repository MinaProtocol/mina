#!/bin/sh
# Configure APT caching proxy with a bypass for the Mina debian package repository,
# AND opt into the o1Labs deb-mirror for Ubuntu base packages on supported codenames.
#
# Usage: configure-apt-proxy.sh [APT_CACHE_URL] [DEB_REPO] [APT_MIRROR_URL]
#   APT_CACHE_URL   - apt-cacher-ng or similar caching proxy URL
#                     (e.g. http://apt-cache-ingress.mirror-ingress:3142)
#   DEB_REPO        - URL of the Mina deb repo that must bypass the proxy
#                     (e.g. http://packages.o1test.net)
#   APT_MIRROR_URL  - Base URL of the o1Labs deb-mirror's aptly publication
#                     (e.g. http://deb-mirror-ingress.mirror-ingress). When
#                     omitted but APT_CACHE_URL looks like an in-cluster
#                     apt-cache-ingress URL, this script derives it by
#                     swapping the service name + dropping the port.
#
# If APT_CACHE_URL is empty the script exits cleanly without writing anything,
# so it remains safe to call unconditionally.
#
# When APT_MIRROR_URL is set (or derivable) and the running OS codename is a
# distribution we mirror today (focal), this script ALSO:
#   - writes /etc/apt/sources.list.d/mirror-ubuntu.list pointing at the local
#     mirror with [trusted=yes] for main+universe across {focal, focal-security,
#     focal-updates}, mirroring the Buildkite ARC agent's existing pattern for
#     docker/postgresql/yarn/buildkite-agent/nodesource.
#   - writes /etc/apt/preferences.d/99-local-mirror with Pin-Priority 900 so the
#     local copy wins over Canonical when both have a package.
#   - writes /etc/apt/apt.conf.d/99error-mode with `Error-Mode "any"` so the
#     broken apt-cacher-ng + Canonical-signed pass-through path (where our
#     unsigned local Release is currently authoritative on the proxy) warns
#     rather than failing apt-get update.
#   - bypasses the apt-cacher-ng proxy for the deb-mirror-ingress hostname so
#     direct mirror requests don't take an extra hop and aren't rewritten by
#     apt-cacher-ng's Remap rules.
#
# Fallback behaviour when the local mirror is unreachable:
#   - mirror-ubuntu.list connections fail; Error-Mode "any" warns and continues.
#   - apt then falls back to the default Canonical sources via apt-cacher-ng.
#   - apt-cacher-ng's Remap-uburep chain has `localhost:8080/ubuntu` first;
#     when aptly-serve is down it connection-refuses and apt-cacher-ng falls
#     through to `archive.ubuntu.com`, which serves canonically-signed
#     InRelease. Package installs succeed via the upstream path.
#   - When both deb-mirror-ingress and apt-cacher-ng are unreachable, the
#     Mina build script's pre-flight curl probe drops apt_cache_url and this
#     script exits early — apt uses the default Canonical sources direct.
#
# Codename detection uses /etc/os-release VERSION_CODENAME — no curl/wget
# dependency on slim base images.
#
# This script can be used both:
#  - Inside Dockerfiles (via COPY + RUN), running BEFORE the first apt-get
#  - Directly in CI shell scripts when apt is invoked on the agent host

set -eu

APT_CACHE_URL="${1:-}"
DEB_REPO="${2:-}"
APT_MIRROR_URL="${3:-}"

# Nothing to configure when no proxy is requested.
[ -n "$APT_CACHE_URL" ] || exit 0

# -----------------------------------------------------------------------------
# 1. Original proxy config.
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 2. Opt into o1Labs deb-mirror for Ubuntu base on supported codenames.
# -----------------------------------------------------------------------------

# Derive APT_MIRROR_URL from APT_CACHE_URL when not passed explicitly.
# Same cluster, parallel service: apt-cache-ingress:3142 -> deb-mirror-ingress (port 80).
if [ -z "$APT_MIRROR_URL" ]; then
    case "$APT_CACHE_URL" in
        *apt-cache-ingress*)
            APT_MIRROR_URL=$(echo "$APT_CACHE_URL" \
                | sed -e 's|apt-cache-ingress|deb-mirror-ingress|' \
                      -e 's|:3142||')
            ;;
    esac
fi

if [ -z "$APT_MIRROR_URL" ]; then
    echo "--- No APT_MIRROR_URL derivable; skipping deb-mirror Ubuntu setup ---"
    exit 0
fi

# Detect codename without curl/wget (slim base images don't ship them).
CODENAME=""
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    CODENAME="${VERSION_CODENAME:-}"
fi

# Today the deb-mirror only publishes Ubuntu focal main+universe (with
# -security and -updates). When mirrors.yaml grows ubuntu-jammy* /
# ubuntu-noble* entries, add the matching codename(s) here.
case "$CODENAME" in
    focal)
        ;;
    "")
        echo "--- /etc/os-release has no VERSION_CODENAME; skipping deb-mirror Ubuntu setup ---"
        exit 0
        ;;
    *)
        echo "--- deb-mirror has no Ubuntu mirror for codename '${CODENAME}'; skipping ---"
        exit 0
        ;;
esac

echo "--- Configuring deb-mirror Ubuntu sources (codename: ${CODENAME}) ---"

# Pin: derive the host from APT_MIRROR_URL (strip scheme and any port).
mirror_host="${APT_MIRROR_URL#*://}"
mirror_host="${mirror_host%%[:/]*}"

cat > /etc/apt/sources.list.d/mirror-ubuntu.list <<EOF
deb [trusted=yes] ${APT_MIRROR_URL}/ubuntu ${CODENAME} main universe
deb [trusted=yes] ${APT_MIRROR_URL}/ubuntu ${CODENAME}-security main universe
deb [trusted=yes] ${APT_MIRROR_URL}/ubuntu ${CODENAME}-updates main universe
EOF

cat > /etc/apt/preferences.d/99-local-mirror <<EOF
Package: *
Pin: origin ${mirror_host}
Pin-Priority: 900
EOF

# Tolerate per-source failures during apt-get update. Two failure modes this
# saves us from:
#   1. mirror-ubuntu.list unreachable (deb-mirror VM / aptly-serve down) →
#      apt logs the connection error and continues; default Canonical sources
#      via apt-cacher-ng still satisfy the install.
#   2. apt-cacher-ng + Canonical-via-proxy returns the unsigned local Release
#      (because acng.conf's Remap-uburep has localhost:8080 first today —
#      gitops-infrastructure tasks/todo.md Bucket 0) → apt warns "is not
#      signed" on the Canonical sources, continues, and the pin above directs
#      installs to mirror-ubuntu.list which IS [trusted=yes].
# Without Error-Mode "any", either warning escalates to a fatal error on
# apt 2.3.15+.
echo 'APT::Update::Error-Mode "any";' > /etc/apt/apt.conf.d/99error-mode

# Tell apt to fetch from the deb-mirror-ingress host DIRECTLY, not through
# apt-cacher-ng. Two reasons: (a) avoid the wasted proxy round-trip; (b)
# avoid apt-cacher-ng's Remap rules being applied to our direct mirror URL.
# Written as a SEPARATE file so we don't have to re-parse + edit the 01proxy
# block written above.
cat > /etc/apt/apt.conf.d/02proxy-bypass-mirror <<EOF
Acquire::http::Proxy::${mirror_host} "DIRECT";
Acquire::https::Proxy::${mirror_host} "DIRECT";
EOF

echo "--- /etc/apt/sources.list.d/mirror-ubuntu.list ---"
cat /etc/apt/sources.list.d/mirror-ubuntu.list
echo "--- /etc/apt/preferences.d/99-local-mirror ---"
cat /etc/apt/preferences.d/99-local-mirror
echo "--- /etc/apt/apt.conf.d/02proxy-bypass-mirror ---"
cat /etc/apt/apt.conf.d/02proxy-bypass-mirror
echo "------------------------"
