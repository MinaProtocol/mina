#!/bin/bash
#
# Entrypoint for the dev/ container that remaps the in-container `opam` user
# to the host user's UID/GID, so files written through the bind-mounted source
# tree come out with host-side ownership instead of UID 65533.
#
# Activation: only takes effect when the container is started as root AND
# MINA_HOST_UID is set. When started as non-root (e.g. CI, which runs as USER
# opam) this is a transparent passthrough — `exec "$@"` runs the original
# command unchanged. When started as root with no MINA_HOST_UID, the script
# bails loudly rather than running as root and writing root-owned files to
# the host-mounted source tree.
#
# Intended use is via dev/docker-compose.yml:
#   user: "0:0"
#   entrypoint: ["/mina/dev/dev-uid-fixup.sh"]
#   environment:
#     MINA_HOST_UID: "${HOST_UID}"
#     MINA_HOST_GID: "${HOST_GID}"
#
# The script is reached via the repo bind-mount (../:/mina), so no
# rebuild of the toolchain image is required.

set -euo pipefail
if [[ "${MINA_UID_FIXUP_DEBUG:-0}" == "1" ]]; then set -x; fi

log() {
  printf '[dev-uid-fixup] %s\n' "$*" >&2
}

err() {
  printf '[dev-uid-fixup] ERROR: %s\n' "$*" >&2
}

# Non-root invocation (CI). Nothing to remap; just pass the command through.
if [[ "$(id -u)" -ne 0 ]]; then
  exec "$@"
fi

# Root invocation without host UID is almost certainly a user running
# `docker compose up` directly without going through dev/Makefile. Refuse
# rather than silently writing root-owned files to the host source tree.
if [[ -z "${MINA_HOST_UID:-}" ]]; then
  err "MINA_HOST_UID is not set. The dev container must be started via"
  err "  make            (in dev/)"
  err "which exports HOST_UID/HOST_GID so this entrypoint can remap the"
  err "in-container opam user to your host UID. Aborting to avoid leaving"
  err "host-side root-owned files behind."
  exit 1
fi

host_uid="${MINA_HOST_UID}"
host_gid="${MINA_HOST_GID:-${host_uid}}"

# Host root → nothing to remap.
if [[ "${host_uid}" -eq 0 ]]; then
  exec "$@"
fi

current_uid="$(id -u opam)"
current_gid="$(id -g opam)"

if [[ "${host_uid}" != "${current_uid}" ]] || [[ "${host_gid}" != "${current_gid}" ]]; then
  # /etc/passwd / /etc/group are baked into the image, so every container
  # boot starts with opam at UID 65533. The remap below has to run on every
  # boot — but the *expensive* chown -R only fires when the named volumes
  # aren't already at the target UID (i.e. first boot of a fresh volume).

  # Free up the target UID/GID first in case another account already owns it.
  existing_user="$(getent passwd "${host_uid}" | cut -d: -f1 || true)"
  if [[ -n "${existing_user}" && "${existing_user}" != "opam" ]]; then
    log "freeing UID ${host_uid} from existing user ${existing_user}"
    sed -i "/^${existing_user}:/d" /etc/passwd /etc/shadow
  fi
  existing_group="$(getent group "${host_gid}" | cut -d: -f1 || true)"
  if [[ -n "${existing_group}" && "${existing_group}" != "opam" ]]; then
    log "freeing GID ${host_gid} from existing group ${existing_group}"
    sed -i "/^${existing_group}:/d" /etc/group
  fi

  # Rewrite /etc/passwd and /etc/group directly. We avoid usermod/groupmod
  # because shadow-utils' usermod triggers an implicit recursive walk of the
  # home directory, which is unbearably slow on this image — /home/opam/.opam
  # holds an opam switch with tens of thousands of files mounted on a named
  # volume.
  sed -i -E "s|^opam:x:[0-9]+:[0-9]+:|opam:x:${host_uid}:${host_gid}:|" /etc/passwd
  sed -i -E "s|^opam:x:[0-9]+:|opam:x:${host_gid}:|"                     /etc/group

  # Only chown when actually needed. Compare top-level ownership against the
  # target UID and recurse only when out of sync.
  fix_owner() {
    local target="$1"
    [[ -e "${target}" ]] || return 0
    local owner
    owner="$(stat -c '%u' "${target}")"
    if [[ "${owner}" != "${host_uid}" ]]; then
      log "chown -R ${host_uid}:${host_gid} ${target} (may take a moment on first boot)"
      chown -R "${host_uid}:${host_gid}" "${target}"
    fi
  }

  # Handle /home/opam carefully. The directory itself and any dotfiles live
  # in the image layer and reset to UID 65533 on every container boot — so
  # we re-chown them each time, but the cost is small (a few inodes).
  #
  # We deliberately do NOT recurse into the heavy image-baked subdirs (.rustup,
  # opam-repository, mina/, go/, etc.) — they hold tens of thousands of files
  # that opam reads but never writes to, and chowning them through overlayfs
  # copy-up costs ~1 minute per boot. Read access works fine at the original
  # UID (755 perms), and the volumes opam *does* write to (/home/opam/.opam,
  # /mina/_opam, /mina/_build) are handled below.
  if [[ -d /home/opam ]]; then
    home_owner="$(stat -c '%u' /home/opam)"
    if [[ "${home_owner}" != "${host_uid}" ]]; then
      log "chown /home/opam (dir + top-level files; image-baked subdirs left as-is)"
      chown "${host_uid}:${host_gid}" /home/opam
      find /home/opam -mindepth 1 -maxdepth 1 -type f \
        -exec chown "${host_uid}:${host_gid}" {} +
    fi
  fi
  fix_owner /home/opam/.opam
  fix_owner /mina/_opam
  fix_owner /mina/_build
fi

exec setpriv --reuid=opam --regid=opam --init-groups -- "$@"
