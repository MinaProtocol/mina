# Developer Setup (Docker)

The Docker-based dev environment is the fastest way to a working Mina
build on any host OS, and pins the **same toolchain CI uses** — so you
won't hit "works on my machine" drift between local and CI.

If you're choosing between this and native install, prefer this one
unless you have a specific reason to install OCaml/opam/Rust/Go on the
host directly.

## Prerequisites

- Docker (with the `docker compose` v2 subcommand).
- ~10 GB of free disk for the toolchain image + the opam switch volume.
- Optional: [VS Code](https://code.visualstudio.com/) with the
  [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  for the IDE path.

## Quick start — terminal

```sh
cd dev
make            # pulls the toolchain image, boots the container

# in a second terminal:
make ssh        # drops you into the container as `opam`, in /mina

# inside the container:
eval "$(opam config env)"
make build      # build the daemon
```

Files you edit on the host are live in the container at `/mina`, and
files the container writes back to your source tree are owned by your
host user — no `sudo chown` step.

## Quick start — VS Code

```sh
cd dev
make devcontainer   # generates .devcontainer/mina/  (gitignored)
```

Then in VS Code: **Command Palette → Dev Containers: Reopen in
Container → Mina toolchain (non-Nix)**. The integrated terminal lands
you in `/mina` as `opam` with OCaml LSP / jump-to-def working.

## What you get

- The same toolchain image CI builds against
  (`docker.io/minaprotocol/mina-toolchain`), pinned to a recent CI commit.
- Host UID/GID remapping at container boot, so writes from inside the
  container come out owned by *you* on the host.
- Named volumes for `.opam`, `_opam`, `_build` so the switch and build
  cache survive container restarts.

For the full reference (overriding the image tag, troubleshooting first-boot
slowness, JetBrains / Neovim flows), see
[`dev/README.md`](../dev/README.md).

## See also

- [Setup on Linux (native)](./setup-linux.md) — install the toolchain
  directly on the host (best-effort; can drift from CI).
- [Setup on macOS (native)](./setup-macos.md)
- [Build Mina with Nix](../nix/README.md) — also reproducible; manages
  the C library + OCaml dependency matrix declaratively.
