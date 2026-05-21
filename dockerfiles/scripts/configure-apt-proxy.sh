#!/bin/sh
# Configure APT for o1Labs CI/build environments:
#   1. Route most apt traffic through an apt-cacher-ng caching proxy
#      (APT_CACHE_URL) while bypassing the Mina deb repo (DEB_REPO) so
#      package publishes don't get cached.
#   2. Unconditionally bypass the proxy for archive.ubuntu.com /
#      security.ubuntu.com. The o1Labs apt-cacher-ng has the local
#      (unsigned) aptly publication first in its Remap-uburep chain — a
#      proxied request for archive.ubuntu.com would get our unsigned
#      Release file, which apt then rejects with "is no longer signed"
#      (anti-downgrade — not soft-recoverable by Error-Mode "any").
#      Sending these DIRECT keeps Canonical default sources verifiable
#      regardless of mirror state. (See gitops-infrastructure PR #1289.)
#   3. Opt into the o1Labs deb-mirror for Ubuntu base packages on
#      allowlisted codenames (focal today; jammy on the roadmap as
#      Ubuntu 22.04 standard support ends). Mirrors the Buildkite ARC
#      agent's [trusted=yes] mirror-ubuntu.list + Pin-Priority 900
#      pattern. (See gitops-infrastructure PR #1287.)
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
# When APT_MIRROR_URL is set (or derivable) AND the running OS codename is in
# the allowlist (focal|jammy), this script also:
#   - writes /etc/apt/sources.list.d/mirror-ubuntu.list pointing at the local
#     mirror with [trusted=yes] for main+universe across {CODENAME,
#     CODENAME-security, CODENAME-updates}, mirroring the Buildkite ARC
#     agent's existing pattern for docker/postgresql/yarn/buildkite-agent/
#     nodesource.
#   - writes /etc/apt/preferences.d/99-local-mirror with Pin-Priority 900 so
#     the local copy wins over Canonical when both have a package.
#   - writes /etc/apt/apt.conf.d/99error-mode with `Error-Mode "any"` so
#     transient per-source failures (mirror unreachable, codename not yet
#     mirrored, etc.) degrade to warnings rather than failing apt-get update.
#   - bypasses the apt-cacher-ng proxy for the deb-mirror-ingress hostname so
#     direct mirror requests don't take an extra hop and aren't rewritten by
#     apt-cacher-ng's Remap rules.
#
# Graceful degradation matrix:
#   * Codename mirrored + mirror up        -> all packages from local mirror
#   * Codename mirrored + mirror down      -> Error-Mode "any" warns on the
#                                             mirror sources; Canonical
#                                             defaults (DIRECT) satisfy the
#                                             install.
#   * Codename allowlisted but not yet
#     mirrored (e.g. jammy today)          -> mirror sources 404; Error-Mode
#                                             "any" warns; Canonical defaults
#                                             (DIRECT) satisfy the install.
#   * Codename not allowlisted             -> mirror setup skipped entirely;
#                                             default Ubuntu sources stand.
#   * Both deb-mirror and apt-cacher-ng
#     unreachable                          -> Mina build script's pre-flight
#                                             curl probe drops APT_CACHE_URL
#                                             and this script exits early —
#                                             apt uses default Canonical
#                                             sources direct.
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
# 1. Caching proxy + DIRECT bypasses.
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
  # Ubuntu Canonical archives ALWAYS go DIRECT (see header note 2):
  # the o1Labs apt-cacher-ng's Remap-uburep chain has the local unsigned
  # aptly publication first, so a proxied request for archive.ubuntu.com
  # would resolve to our unsigned Release and apt would refuse it as
  # "is no longer signed". Bypassing the proxy for these two hosts keeps
  # Canonical defaults verifiable regardless of mirror state.
  echo "Acquire::http::Proxy::archive.ubuntu.com \"DIRECT\";"
  echo "Acquire::https::Proxy::archive.ubuntu.com \"DIRECT\";"
  echo "Acquire::http::Proxy::security.ubuntu.com \"DIRECT\";"
  echo "Acquire::https::Proxy::security.ubuntu.com \"DIRECT\";"
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

# Codename allowlist. Today the deb-mirror only publishes Ubuntu focal
# main+universe (with -security and -updates); jammy is on the near-term
# roadmap as Ubuntu 22.04 standard support ends. With Error-Mode "any" plus
# the Canonical-DIRECT bypass written above, listing a codename here BEFORE
# the deb-mirror serves it is safe: mirror-ubuntu.list 404s with a warning,
# apt continues, and the install completes from Canonical defaults. Add
# noble (or other future codenames) the same way.
case "$CODENAME" in
    focal|jammy)
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

# Tolerate per-source failures during apt-get update. Without Error-Mode
# "any", these escalate to a fatal apt-get update on apt 2.3.15+:
#   1. mirror-ubuntu.list unreachable (deb-mirror VM / aptly-serve down).
#   2. Codename allowlisted here but not yet mirrored (e.g. jammy today) —
#      the mirror's Release endpoint returns 404 for the configured pocket.
# In both cases the apt-cacher-ng + Canonical-DIRECT bypass from Section 1
# means archive.ubuntu.com / security.ubuntu.com are still reachable with
# valid signatures, so the install completes from Canonical defaults.
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
