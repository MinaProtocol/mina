#!/bin/sh
# Configure APT for o1Labs CI/build environments:
#   1. Route most apt traffic through an apt-cacher-ng caching proxy
#      (APT_CACHE_URL) while bypassing the known Mina deb repo hosts, so
#      package publishes don't get cached. The bypass list is fixed, not
#      derived from a per-build repo argument: packages.o1test.net redirects
#      http -> https at the CDN, and apt-cacher-ng cannot follow a redirect to
#      TLS for a cached remote -- it returns "500 Remote or cache error" and
#      apt fails hard with
#      "E: Failed to fetch .../InRelease  500  Remote or cache error".
#   2. Unconditionally bypass the proxy for archive.ubuntu.com /
#      security.ubuntu.com. The o1Labs apt-cacher-ng has the local
#      (unsigned) apt repository publication first in its Remap-uburep chain — a
#      proxied request for archive.ubuntu.com would get our unsigned
#      Release file, which apt then rejects with "is no longer signed"
#      (anti-downgrade). Sending these DIRECT keeps Canonical default
#      sources verifiable regardless of mirror state. (See gitops-
#      infrastructure PR #1289.)
#   3. Opt into the o1Labs deb-mirror for OS base packages on allowlisted
#      codenames. ONLY codenames the deb-mirror actually serves today
#      belong in the allowlist — apt-get update fails fatally on 404s
#      for an allowlisted-but-unmirrored codename (Error-Mode "any" is
#      the strict default; it does NOT demote fetch failures to
#      warnings, only "is no longer signed" downgrades).
#      Today:
#        - focal (Ubuntu 20.04)    → ${APT_MIRROR_URL}/ubuntu/, components main universe
#        - bullseye (Debian 11)    → ${APT_MIRROR_URL}/debian/,  components main
#      The Ubuntu side writes mirror-ubuntu.list; the Debian side writes
#      mirror-debian.list (both pinned at the default priority 500 — see
#      below for why we don't override-pin).
#      Extension procedure when adding jammy / bookworm / noble / future
#      codenames:
#        a. gitops-infrastructure PR: add mirror entries to
#           platform/hetzner-cloud/deb-mirror/mirrors.yaml, sync via
#           `./mirror-ctl.sh sync-running deb-mirror-1`, verify
#           `curl /<prefix>/dists/<codename>/Release` returns 200 with
#           the expected Components.
#        b. gitops-infrastructure PR: extend mirror-ubuntu.list (or its
#           Debian equivalent) in platform/hetzner-rivendell-1/
#           applications/buildkite-agents/entrypoint{,-development}.yaml.gotmpl.
#        c. ONLY THEN, this allowlist (mirrors the Buildkite ARC agent's
#           [trusted=yes] mirror-ubuntu.list pattern, see gitops-
#           infrastructure PR #1287).
#
# Usage: configure-apt-proxy.sh [APT_CACHE_URL] [APT_MIRROR_URL]
#   APT_CACHE_URL   - apt-cacher-ng or similar caching proxy URL
#                     (e.g. http://apt-cache-ingress.mirror-ingress:3142)
#   APT_MIRROR_URL  - Base URL of the o1Labs deb-mirror's apt repository publication
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
#     the local mirror with [trusted=yes] across {CODENAME, CODENAME-security,
#     CODENAME-updates}. Ubuntu codenames use components "main universe" and
#     the /ubuntu URL prefix; Debian codenames use "main" and /debian. This
#     mirrors the Buildkite ARC agent's existing pattern for docker/postgresql/
#     yarn/buildkite-agent/nodesource.
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
APT_MIRROR_URL="${2:-}"

# Nothing to configure when no proxy is requested.
[ -n "$APT_CACHE_URL" ] || exit 0

# -----------------------------------------------------------------------------
# 1. Caching proxy + DIRECT bypasses.
# -----------------------------------------------------------------------------
conf=/etc/apt/apt.conf.d/01proxy
{
  echo "Acquire::http::Proxy \"${APT_CACHE_URL}\";"
  echo "Acquire::https::Proxy \"${APT_CACHE_URL}\";"
  # The Mina deb repos ALWAYS go DIRECT (see header note 1).
  # packages.o1test.net redirects http -> https at the CDN, and apt-cacher-ng
  # cannot follow a redirect to TLS for a cached remote: it answers
  # "500 Remote or cache error", which apt treats as fatal. Fetched directly the
  # same request succeeds (the 404s on InRelease/Release.gpg are expected for an
  # unsigned repo and are demoted to Ign).
  MINA_DEB_REPO_HOSTS="packages.o1test.net
unstable.apt.packages.minaprotocol.com
nightly.apt.packages.minaprotocol.com
stable.apt.packages.minaprotocol.com"
  for mina_repo_host in $MINA_DEB_REPO_HOSTS; do
    echo "Acquire::http::Proxy::${mina_repo_host} \"DIRECT\";"
    echo "Acquire::https::Proxy::${mina_repo_host} \"DIRECT\";"
  done
  # Ubuntu Canonical archives ALWAYS go DIRECT (see header note 2):
  # the o1Labs apt-cacher-ng's Remap-uburep chain has the local unsigned
  # apt repository publication first, so a proxied request for archive.ubuntu.com
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
#      that the Components line matches what you set below.
#   2. gitops-infrastructure PR — extend the relevant mirror-*.list block in
#      platform/hetzner-rivendell-1/applications/buildkite-agents/
#      entrypoint{,-development}.yaml.gotmpl with the new codename triple.
#   3. ONLY THEN, this allowlist + matching MIRROR_URL_PREFIX / MIRROR_COMPONENTS
#      / MIRROR_LIST entry.
# MIRROR_AUTHORITATIVE=1 additionally DISABLES the distro's own sources once the
# mirror is proven reachable (see "3." below). Set it only for codenames whose
# upstream archive is past EOL and therefore actively rotting; leave it 0 while
# upstream is healthy, so a mirror outage is a non-event.
case "$CODENAME" in
    focal)
        MIRROR_LIST=/etc/apt/sources.list.d/mirror-ubuntu.list
        MIRROR_URL_PREFIX="${APT_MIRROR_URL}/ubuntu"
        MIRROR_COMPONENTS="main universe"
        # Canonical still serves focal (via archive.ubuntu.com, and eventually
        # old-releases). Stay additive: the mirror is a fast path, not the only
        # path. Flip to 1 if/when archive.ubuntu.com starts failing for focal.
        MIRROR_AUTHORITATIVE=0
        ;;
    bullseye)
        # Debian 11. Mina daemon's default Docker base image. Mirrored as the
        # publish_prefix=debian publication added in gitops-infrastructure
        # PR #1361. We only mirror Debian's `main` (no contrib / non-free)
        # today; extend mirrors.yaml first if a build ever needs them.
        MIRROR_LIST=/etc/apt/sources.list.d/mirror-debian.list
        MIRROR_URL_PREFIX="${APT_MIRROR_URL}/debian"
        MIRROR_COMPONENTS="main"
        # Bullseye left LTS on 2026-08-31. deb.debian.org stopped re-signing
        # bullseye-security: its Release carries Valid-Until 2026-09-07 and will
        # never be refreshed again, so apt rejects it with
        #   E: Release file for .../bullseye-security/InRelease is expired
        # and apt-get update exits 100 -- fatal inside a Docker build. Keeping
        # upstream in the source list is now a pure liability: it contributes
        # nothing the mirror does not already have (verified: identical package
        # counts, 58657 in bullseye/main and 3816 in bullseye-security/main)
        # and it is the only thing that can fail. Make the mirror authoritative.
        MIRROR_AUTHORITATIVE=1
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

echo "--- Configuring deb-mirror sources (codename: ${CODENAME}, prefix: ${MIRROR_URL_PREFIX}, components: ${MIRROR_COMPONENTS}) ---"

# Derive host from APT_MIRROR_URL (strip scheme and any port) for the proxy
# bypass below.
mirror_host="${APT_MIRROR_URL#*://}"
mirror_host="${mirror_host%%[:/]*}"

cat > "$MIRROR_LIST" <<EOF
deb [trusted=yes] ${MIRROR_URL_PREFIX} ${CODENAME} ${MIRROR_COMPONENTS}
deb [trusted=yes] ${MIRROR_URL_PREFIX} ${CODENAME}-security ${MIRROR_COMPONENTS}
deb [trusted=yes] ${MIRROR_URL_PREFIX} ${CODENAME}-updates ${MIRROR_COMPONENTS}
EOF

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
echo "--- /etc/apt/apt.conf.d/02proxy-bypass-mirror ---"
cat /etc/apt/apt.conf.d/02proxy-bypass-mirror
echo "------------------------"

# -----------------------------------------------------------------------------
# 3. For EOL codenames, make the mirror AUTHORITATIVE (drop upstream entirely).
# -----------------------------------------------------------------------------
# Rationale: once a codename leaves LTS, upstream stops re-signing the security
# Release. apt then rejects it as expired and fails apt-get update outright --
# see the bullseye note in the codename case above. Leaving upstream in the list
# adds no packages the mirror lacks and adds one guaranteed future failure.
#
# We do NOT blindly delete the distro sources: if the mirror is unreachable that
# would leave the image with no apt sources at all. Instead apt itself probes
# the mirror -- using ONLY ${MIRROR_LIST} as its source list -- and upstream is
# disabled only on success. On failure we keep upstream and relax just the
# freshness check, which is the best that can be done without the mirror.
[ "${MIRROR_AUTHORITATIVE:-0}" = "1" ] || exit 0

echo "--- deb-mirror is authoritative for ${CODENAME}; probing it before disabling upstream ---"
if apt-get update --quiet \
        -o Dir::Etc::sourcelist="$MIRROR_LIST" \
        -o Dir::Etc::sourceparts="/dev/null" \
        -o APT::Get::List-Cleanup="0" >/dev/null 2>&1; then
    echo "--- probe OK: disabling upstream ${CODENAME} sources ---"
    # Keep an EMPTY /etc/apt/sources.list rather than removing it: later build
    # steps (dockerfiles/stages/1-base-deps "Switch to HTTPS") branch on
    # `[ -f /etc/apt/sources.list ]` and would otherwise sed a file that does
    # not exist. Third-party lists under sources.list.d are left untouched.
    #
    # This script runs more than once per image: in 1-base-deps, and again in
    # every stage that starts FROM a published mina-base (2-mina-daemon,
    # 4-auto-hardfork, 2-mina-archive) because CI reuses that base via
    # --base-image and skips 1-base-deps entirely. Only back up a NON-EMPTY
    # sources.list, and never overwrite an existing backup, so a second run on
    # an already-emptied base cannot clobber the real upstream list with an
    # empty file.
    if [ -s /etc/apt/sources.list ] && [ ! -f /etc/apt/sources.list.disabled-by-deb-mirror ]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.disabled-by-deb-mirror
    fi
    if [ -f /etc/apt/sources.list ]; then
        : > /etc/apt/sources.list
    fi
    # deb822 layout (bookworm and newer base images).
    for deb822 in /etc/apt/sources.list.d/debian.sources \
                  /etc/apt/sources.list.d/ubuntu.sources; do
        if [ -f "$deb822" ]; then
            mv "$deb822" "${deb822}.disabled-by-deb-mirror"
        fi
    done
    echo "--- upstream sources disabled; deb-mirror is the only OS package source ---"
else
    echo "--- probe FAILED: deb-mirror unreachable or not serving ${CODENAME} ---"
    echo "--- dropping the mirror list and falling back to upstream ---"
    # Leaving an unreachable source in the list is not harmless: apt-get update
    # fails fatally on a source it cannot fetch, so keeping mirror-*.list around
    # would break the very build we are trying to rescue.
    rm -f "$MIRROR_LIST"
    # If an earlier run of this script (1-base-deps, or the published mina-base
    # this stage starts FROM) already made the mirror authoritative, the distro
    # sources are empty/moved aside. Put them back, or apt is left with no OS
    # package source at all.
    if [ ! -s /etc/apt/sources.list ] && [ -s /etc/apt/sources.list.disabled-by-deb-mirror ]; then
        cp /etc/apt/sources.list.disabled-by-deb-mirror /etc/apt/sources.list
        echo "--- restored /etc/apt/sources.list from the deb-mirror backup ---"
    fi
    for deb822 in /etc/apt/sources.list.d/debian.sources \
                  /etc/apt/sources.list.d/ubuntu.sources; do
        if [ ! -f "$deb822" ] && [ -f "${deb822}.disabled-by-deb-mirror" ]; then
            mv "${deb822}.disabled-by-deb-mirror" "$deb822"
        fi
    done
    # Upstream is all we have left, and for an EOL codename its Release file is
    # expired. Signatures are still verified; only Valid-Until is skipped.
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-valid-until
    # apt-cacher-ng and the deb-mirror run on the SAME host, so a probe failure
    # usually means the caching proxy is down too. 01proxy routes deb.debian.org
    # through that proxy (it is not in the DIRECT list), which would make the
    # upstream fallback fail for exactly the reason we are falling back. Send
    # the Debian archives DIRECT so the fallback does not depend on the box we
    # just failed to reach.
    cat > /etc/apt/apt.conf.d/03proxy-bypass-fallback <<'FBEOF'
Acquire::http::Proxy::deb.debian.org "DIRECT";
Acquire::https::Proxy::deb.debian.org "DIRECT";
Acquire::http::Proxy::security.debian.org "DIRECT";
Acquire::https::Proxy::security.debian.org "DIRECT";
Acquire::http::Proxy::archive.debian.org "DIRECT";
Acquire::https::Proxy::archive.debian.org "DIRECT";
FBEOF
fi

echo "--- effective OS package sources ---"
# Informational only. `|| true` matters: under `set -e`, an unmatched *.list
# glob (nothing left in sources.list.d after the fallback removed the mirror
# list) would make cat fail and turn a successful fallback into a failed RUN.
cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list 2>/dev/null || true
echo "------------------------"
