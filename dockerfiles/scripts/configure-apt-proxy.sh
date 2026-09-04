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
#   3. Opt into the o1Labs deb-mirror for OS base packages on allowlisted
#      codenames. ONLY codenames the deb-mirror actually
#      serves today belong in the allowlist — apt-get update fails
#      fatally on 404s for an allowlisted-but-unmirrored codename
#      (Error-Mode "any" is the strict default; it does NOT demote
#      fetch failures to warnings, only "is no longer signed" downgrades).
#      Today:
#        - focal (Ubuntu 20.04)  → ${APT_MIRROR_URL}/ubuntu/, components main universe
#        - bullseye (Debian 11)  → ${APT_MIRROR_URL}/debian/,  components main
#      For Debian codenames the stock deb.debian.org entries are also moved
#      BEHIND the mirror in apt's parse order, so the mirror actually serves
#      the downloads — see the "must be parsed first" block below for the
#      measurement and for the deb.debian.org 404 that motivated it.
#      Extension procedure when adding a new codename (jammy, bookworm, …):
#        a. gitops-infrastructure PR: add mirror entries to
#           platform/hetzner-cloud/deb-mirror/mirrors.yaml, sync via
#           `./mirror-ctl.sh sync-running deb-mirror-1`, verify
#           `curl /<prefix>/dists/<codename>/Release` returns 200 with
#           the expected Components.
#        b. gitops-infrastructure PR: extend mirror-ubuntu.list (or its
#           Debian equivalent) in
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
# the allowlist (focal, bullseye), this script also:
#   - writes /etc/apt/sources.list.d/mirror-{ubuntu,debian}.list pointing at
#     the local mirror with [trusted=yes] across {CODENAME,
#     CODENAME-security, CODENAME-updates}, mirroring the Buildkite ARC
#     agent's existing pattern for docker/postgresql/yarn/buildkite-agent/
#     nodesource. Ubuntu codenames use components "main universe" and the
#     /ubuntu URL prefix; Debian codenames use "main" and /debian.
#   - for Debian codenames only, moves the stock /etc/apt/sources.list
#     entries to /etc/apt/sources.list.d/10-debian.list so the mirror is
#     parsed — and therefore downloaded from — first.
#   - does NOT pin the mirror with Pin-Priority. Pinning at >500 over-broadens:
#     it would force apt to prefer OUR Ubuntu-version of a package even when a
#     third-party repo (e.g. postgresql.org → postgresql-15) needs a strictly-
#     newer version of an Ubuntu base library (libpq5 12.22 vs 15.x). The
#     local mirror is still used when apt picks it on its own (versions equal
#     to Canonical), and traffic still goes through it; it just doesn't
#     override version-driven dependency resolution.
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
# unmirrored codename. Today:
#   focal     (Ubuntu 20.04, /ubuntu prefix, "main universe")
#   bullseye  (Debian 11,    /debian prefix, "main")
#
# Procedure for adding jammy / bookworm / noble / future codenames:
#   1. gitops-infrastructure PR — add <distro>-<codename>* mirror entries to
#      platform/hetzner-cloud/deb-mirror/mirrors.yaml. Sync via
#      `./mirror-ctl.sh sync-running deb-mirror-1`. Verify with
#      `curl http://deb-mirror-ingress.mirror-ingress/<prefix>/dists/<codename>/Release`
#      that the Components line matches MIRROR_COMPONENTS below.
#   2. gitops-infrastructure PR — extend the matching mirror-*.list block in
#      platform/hetzner-rivendell-1/applications/buildkite-agents/
#      entrypoint{,-development}.yaml.gotmpl with the new codename triple.
#   3. ONLY THEN, this allowlist + its MIRROR_* values.
#
# MIRROR_FIRST=yes additionally takes the distro's own archive out of the
# download path — see the "must be parsed first" block below. Debian
# codenames set it; focal keeps its historical behaviour untouched.
case "$CODENAME" in
    focal)
        MIRROR_LIST=/etc/apt/sources.list.d/mirror-ubuntu.list
        MIRROR_URL_PREFIX="${APT_MIRROR_URL}/ubuntu"
        MIRROR_COMPONENTS="main universe"
        MIRROR_FIRST=no
        ;;
    bullseye)
        # Debian 11. Base image of the daemon, archive, test-suite,
        # txn-burst and zkapp-test-transaction images. Mirrored as the
        # publish_prefix=debian publication (gitops-infrastructure PR #1361).
        # We mirror Debian's `main` only (no contrib / non-free); extend
        # mirrors.yaml first if a build ever needs them.
        MIRROR_LIST=/etc/apt/sources.list.d/00-mirror-debian.list
        MIRROR_URL_PREFIX="${APT_MIRROR_URL}/debian"
        MIRROR_COMPONENTS="main"
        MIRROR_FIRST=yes
        ;;
    "")
        echo "--- /etc/os-release has no VERSION_CODENAME; skipping deb-mirror setup ---"
        exit 0
        ;;
    *)
        echo "--- deb-mirror has no mirror for codename '${CODENAME}'; skipping ---"
        exit 0
        ;;
esac

echo "--- Configuring deb-mirror sources (codename: ${CODENAME}, prefix: ${MIRROR_URL_PREFIX}, components: ${MIRROR_COMPONENTS}, mirror-first: ${MIRROR_FIRST}) ---"

# Derive host from APT_MIRROR_URL (strip scheme and any port) for the proxy
# bypass below.
mirror_host="${APT_MIRROR_URL#*://}"
mirror_host="${mirror_host%%[:/]*}"

cat > "$MIRROR_LIST" <<EOF
deb [trusted=yes] ${MIRROR_URL_PREFIX} ${CODENAME} ${MIRROR_COMPONENTS}
deb [trusted=yes] ${MIRROR_URL_PREFIX} ${CODENAME}-security ${MIRROR_COMPONENTS}
deb [trusted=yes] ${MIRROR_URL_PREFIX} ${CODENAME}-updates ${MIRROR_COMPONENTS}
EOF

# -----------------------------------------------------------------------------
# The mirror must be PARSED FIRST, or it never serves a single download.
#
# apt selects the candidate VERSION by pin priority, but it downloads that
# version from the FIRST source that offers it, in parse order:
# /etc/apt/sources.list, then /etc/apt/sources.list.d/*.list sorted by name.
# Measured on debian:bullseye-slim against a local mirror carrying the same
# version of `jq` as deb.debian.org:
#   mirror in sources.list.d, no pin   -> apt fetched deb.debian.org
#   mirror in sources.list.d, pin 900  -> apt fetched deb.debian.org
#   mirror first inside sources.list   -> apt fetched the mirror
# A Pin-Priority file therefore cannot redirect the traffic (and pinning has
# its own regression history — see the note below).
#
# This is not only about cache hit rate. deb.debian.org currently answers
# "404 Not Found" for the percent-encoded form of some pool paths, which is
# exactly the form apt requests. On 2026-09-04 it broke the archive image on
#   gnupg_2.2.27-2%2bdeb11u3_all.deb  404  Not Found
# while gnupg_2.2.27-2+deb11u3_all.deb and ..._2.2.27-2%2Bdeb11u3_all.deb both
# returned the real 825432-byte package (`x-cache: HIT` on all three, so it is
# served that way, not a transient miss). 11 of 40 sampled bullseye-security
# pool files containing "+" behaved the same. A 404 on a .deb is fatal, and
# it reproduces on a stock debian:bullseye-slim with no proxy at all.
#
# So for Debian codenames the stock entries move to a later-sorted file and
# /etc/apt/sources.list is emptied. Parse order becomes 00-mirror-debian.list
# then 10-debian.list: the mirror serves every package it carries, and Debian
# stays as the fallback for anything it does not.
#
# The moved entries keep their http:// scheme. The Dockerfiles switch
# sources.list to https AFTER installing ca-certificates; that sed now edits
# an emptied file. Deliberate: this branch only runs when APT_CACHE_URL is
# set (CI), where apt already goes through the in-cluster caching proxy --
# which cannot cache a TLS remote anyway. A build without APT_CACHE_URL exits
# at the top of this script and keeps the https switch.
if [ "$MIRROR_FIRST" = "yes" ] && [ -s /etc/apt/sources.list ]; then
    grep -E '^[[:space:]]*deb(-src)?[[:space:]]' /etc/apt/sources.list \
        > /etc/apt/sources.list.d/10-debian.list || :
    cat > /etc/apt/sources.list <<'EOF'
# Emptied by configure-apt-proxy.sh: the o1Labs deb-mirror has to be the first
# source apt parses, and no file under sources.list.d can precede this one.
# The stock entries live in /etc/apt/sources.list.d/10-debian.list.
EOF
fi

# No Pin-Priority file. Earlier versions of this script wrote
# /etc/apt/preferences.d/99-local-mirror with Pin-Priority 900 to "prefer the
# local mirror over Canonical". That over-broadened: apt would prefer
# OUR Ubuntu-version libpq5 (12.22 from focal/main) at priority 900 over the
# postgresql.org repo's libpq5 15.x (priority 500) needed transitively by
# postgresql-15 — breaking the rosetta-focal build with "Unable to correct
# problems, you have held broken packages". Letting the mirror sit at the
# default priority (500) gives the right behavior: same Ubuntu-base versions
# in both Canonical and our mirror → apt picks one (we still serve the
# traffic), but third-party repos with a strictly-newer required version
# still win dependency resolution.

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

echo "--- ${MIRROR_LIST} ---"
cat "$MIRROR_LIST"
if [ -f /etc/apt/sources.list.d/10-debian.list ]; then
    echo "--- /etc/apt/sources.list.d/10-debian.list (moved out of sources.list) ---"
    cat /etc/apt/sources.list.d/10-debian.list
fi
echo "--- /etc/apt/apt.conf.d/02proxy-bypass-mirror ---"
cat /etc/apt/apt.conf.d/02proxy-bypass-mirror
echo "------------------------"
