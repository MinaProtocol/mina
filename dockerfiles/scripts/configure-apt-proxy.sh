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
#      (anti-downgrade). Sending these DIRECT keeps Canonical default
#      sources verifiable regardless of mirror state. (See gitops-
#      infrastructure PR #1289.)
#   3. Opt into the o1Labs deb-mirror for Ubuntu base packages on
#      allowlisted codenames. ONLY codenames the deb-mirror actually
#      serves today belong in the allowlist — apt-get update fails
#      fatally on 404s for an allowlisted-but-unmirrored codename
#      (Error-Mode "any" is the strict default; it does NOT demote
#      fetch failures to warnings, only "is no longer signed" downgrades).
#      Today: focal only. Extension procedure when adding a new
#      codename (jammy, bullseye, …):
#        a. gitops-infrastructure PR: add mirror entries to
#           platform/hetzner-cloud/deb-mirror/mirrors.yaml, sync via
#           `./mirror-ctl.sh sync-running deb-mirror-1`, verify
#           `curl /ubuntu/dists/<codename>/Release` returns 200 with
#           `Components: main universe`.
#        b. gitops-infrastructure PR: extend mirror-ubuntu.list in
#           platform/hetzner-rivendell-1/applications/buildkite-agents/
#           entrypoint{,-development}.yaml.gotmpl.
#        c. ONLY THEN, this allowlist (mirrors the Buildkite ARC agent's
#           [trusted=yes] mirror-ubuntu.list + Pin-Priority 900 pattern,
#           see gitops-infrastructure PR #1287).
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
# the allowlist (focal today), this script also:
#   - writes /etc/apt/sources.list.d/mirror-ubuntu.list pointing at the local
#     mirror with [trusted=yes] for main+universe across {CODENAME,
#     CODENAME-security, CODENAME-updates}, mirroring the Buildkite ARC
#     agent's existing pattern for docker/postgresql/yarn/buildkite-agent/
#     nodesource.
#   - writes /etc/apt/preferences.d/99-local-mirror with Pin-Priority 900 so
#     the local copy wins over Canonical when both have a package.
#   - writes /etc/apt/apt.conf.d/99error-mode with `Error-Mode "any"` — apt's
#     default and explicit-strict mode. Kept as-is for parity with the agent
#     entrypoint; it does not soften 404 errors but documents intent.
#   - bypasses the apt-cacher-ng proxy for the deb-mirror-ingress hostname so
#     direct mirror requests don't take an extra hop and aren't rewritten by
#     apt-cacher-ng's Remap rules.
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

# Codename allowlist. ONLY codenames the deb-mirror actually serves belong
# here — apt-get update fails fatally on 404s for an allowlisted-but-
# unmirrored codename. Today: focal only.
#
# Procedure for adding jammy / bullseye / noble / future codenames:
#   1. gitops-infrastructure PR — add ubuntu-<codename>* mirror entries to
#      platform/hetzner-cloud/deb-mirror/mirrors.yaml. Sync via
#      `./mirror-ctl.sh sync-running deb-mirror-1`. Verify with
#      `curl http://deb-mirror-ingress.mirror-ingress/ubuntu/dists/<codename>/Release`
#      that Components includes "main universe".
#   2. gitops-infrastructure PR — extend mirror-ubuntu.list in
#      platform/hetzner-rivendell-1/applications/buildkite-agents/
#      entrypoint{,-development}.yaml.gotmpl with the new codename triple.
#   3. ONLY THEN, this allowlist.
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

# `Error-Mode "any"` is apt's default-and-strict mode. It demotes one
# specific class of error — "is no longer signed" anti-downgrade — to a
# warning. It does NOT soften per-source 404s or connection failures;
# those still fail apt-get update fatally. Mirrors the agent entrypoint;
# kept for parity and explicit intent.
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
