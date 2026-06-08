# Mina dev container — the non-Nix path

A Docker-based dev environment that pulls in the same toolchain CI uses
(OCaml/opam, Rust, Go, system libs). This is the recommended path when:

- You don't want to install Nix.
- Your host OS isn't covered by the native Linux/macOS guides.
- You want a one-command dev shell with everything pre-installed.

For other paths see the top-level [`README-dev.md`](../README-dev.md).

> Note: this container matches CI's **toolchain**, not its **runtime**. The
> dev container boots as root, runs a small UID-remap entrypoint, then
> drops to `opam`. Use it for builds and iteration — for reproducing
> CI-specific runtime behavior, use the local CI runner in
> [`buildkite/local/`](../buildkite/local/) instead.

## Prerequisites

- Docker (with the `docker compose` v2 subcommand).
- ~10 GB of free disk for the toolchain image + the opam switch volume.
- Optional: [VS Code](https://code.visualstudio.com/) with the
  [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  for the IDE path below.

## Quick start — terminal only

```sh
cd dev
make start      # pulls the toolchain image, boots the container

# in a second terminal:
make ssh        # drops you into the container as `opam`, in /mina

# inside the container:
eval "$(opam config env)"
make build      # build the daemon
```

That's it. Files you edit on the host are live in the container at `/mina`,
and files you create inside the container land back on the host with your
own UID/GID — no `sudo chown` step.

The container also bind-mounts the host Docker socket at
`/var/run/docker.sock`, so Docker-backed local integration tests such as
`mina-test-executive local ...` use the host Docker daemon rather than a
nested Docker daemon. This is Docker-outside-of-Docker, not DinD. It avoids
privileged nested containers and lets the test executive manage the same
Docker Swarm/stack resources you would see from the host with `docker stack
ls`. The VS Code devcontainer init script auto-detects `DOCKER_SOCKET`,
`DOCKER_HOST=unix://...`, `/var/run/docker.sock`, and
`$XDG_RUNTIME_DIR/docker.sock`. For terminal-only use, if your Docker socket
lives somewhere else, set `DOCKER_SOCKET` before starting the dev environment:

```sh
export DOCKER_SOCKET="$XDG_RUNTIME_DIR/docker.sock"
cd dev
make start
```

`make` prints the available commands. `make stop` stops the Compose service.
`make rebuild` wipes the named volumes and rebuilds from scratch — use it after
a major toolchain bump or when the opam switch gets into a weird state.

## Quick start — VS Code

The VS Code Dev Container scaffold is **opt-in** — it's not at the repo
root by default, to avoid pushing a "Reopen in Container?" prompt on
anyone who'd rather use a different editor or their own setup. To enable
it:

```sh
cd dev
make devcontainer   # copies template → <repo>/.devcontainer/mina/  (gitignored)
```

The scaffold lands under `.devcontainer/mina/`, not `.devcontainer/`
itself, so it coexists cleanly with any existing devcontainer config you
may already have in this repo (e.g. your own `.devcontainer/devcontainer.json`
or `.devcontainer/<other-config>/`). VS Code will list both as labeled
options when you "Reopen in Container".

With the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
installed:

1. Open the repo in VS Code.
2. Command Palette → **Dev Containers: Reopen in Container** → pick
   **Mina toolchain (non-Nix)** if prompted.
3. Wait for first-time setup (image pull, opam-lsp-server install — ~5 min
   the first time, fast after).
4. The integrated terminal lands you in `/mina` as `opam`, with the OCaml
   Platform extension pre-installed.

What this gives you on top of the terminal flow:

- OCaml LSP-driven jump-to-definition, type-on-hover, go-to-references.
- An integrated terminal that's already inside the container.
- All extensions installed *inside the container*, so your host VS Code
  stays clean and reproducible across machines.

Shutting the VS Code window down stops the compose project; reopening
reuses the persisted volumes (fast boot).

The generated `.devcontainer/mina/` is yours — customize it freely
(extra extensions, settings, etc.). To refresh from the template, delete
that subdirectory and re-run `make devcontainer`. Your other configs at
`.devcontainer/devcontainer.json` or `.devcontainer/<other>/` are
untouched.

## Quick start — other IDEs

Any editor with a "run / attach to docker container" workflow works:

- **JetBrains** (IntelliJ, CLion, etc.) — Start the container with `make`,
  then in the IDE: *File → Remote Development → Docker → Attach to running
  container* → pick `mina`.
- **Neovim / other CLI editors** — `make ssh` and edit from inside the
  container. Install `ocaml-lsp-server` once via
  `opam install ocaml-lsp-server` if you want LSP features.

For all editor paths: the container's `opam` user has your host UID/GID
after the entrypoint remap, so editor file writes land with sane host
ownership.

## Image source

The default image is pulled from
[`docker.io/minaprotocol/mina-toolchain`](https://hub.docker.com/r/minaprotocol/mina-toolchain/tags),
the public mirror of the Mina toolchain images. CI itself pulls from an
internal Artifact Registry (see `minaToolchain` in
[`buildkite/src/Constants/ContainerImages.dhall`](../buildkite/src/Constants/ContainerImages.dhall))
which isn't publicly accessible, so the dev pin tracks the latest tag
mirrored to docker.io rather than CI's exact commit pin — close enough
for local development, and usually within a few commits of CI.

If the pinned tag ever returns `manifest unknown` (tags do age out),
browse the link above and pick another tag, then either edit
`docker-compose.yml` or set `MINA_TOOLCHAIN_IMAGE` for a one-off run:

```sh
export MINA_TOOLCHAIN_IMAGE=docker.io/minaprotocol/mina-toolchain:<tag>
make
```

You can also use this knob to switch to `bookworm` / `noble` / `focal`
variants without editing the file.

## How container UIDs are handled

The toolchain image's `opam` user is UID 65533, but the source tree is
bind-mounted from the host into `/mina`, so any writes from inside the
container would land on the host with that UID — which is none of the
things your shell calls "yours". To avoid that, the container uses a small
entrypoint ([`dev-uid-fixup.sh`](./dev-uid-fixup.sh)) that boots as root,
rewrites `opam`'s entry in `/etc/passwd`/`/etc/group` to match the host's
UID/GID, chowns the named volumes accordingly, then drops privileges via
`setpriv`. The host UID/GID are passed in either by `dev/Makefile`
(`HOST_UID=$(id -u) HOST_GID=$(id -g)`) for the terminal flow, or by
[`dev/devcontainer-template/init.sh`](./devcontainer-template/init.sh)
writing `dev/.env` for the VS Code flow (copied to `.devcontainer/mina/`
by `make devcontainer`).

The script lives in this directory and is reached through the repo
bind-mount at `/mina/dev/dev-uid-fixup.sh` — no toolchain image rebuild
is required. CI continues to use the stock image (USER `opam`, no
entrypoint override) and the entrypoint is a transparent passthrough
when started as non-root.

> **Don't bypass `make` / VS Code.** If you run `docker compose up`
> directly without the env vars set, the entrypoint will refuse to start
> rather than silently pick UID 1000 (or worse, run as root and write
> root-owned files into your source tree). Use `make` for terminal use
> and *Reopen in Container* for VS Code.

> **First-boot cost.** The first time you start fresh volumes, the
> entrypoint has to `chown -R /home/opam/.opam` (the opam switch inside
> the named volume), which takes a few seconds on most images and up to
> ~1 minute on heavier ones. Subsequent boots short-circuit — the script
> checks the top-level target ownership and only recurses when out of
> sync.

## Invocation constraints

- **Always run compose against `dev/docker-compose.yml`** — either via
  `make` in `dev/`, via `docker compose -f dev/docker-compose.yml ...`
  from elsewhere, or via the VS Code Dev Container (which uses the
  copied `.devcontainer/mina/devcontainer.json`'s `dockerComposeFile`
  reference).
  The bind-mount (`../:/mina`) and entrypoint path
  (`/mina/dev/dev-uid-fixup.sh`) assume the compose file lives at
  `<repo>/dev/docker-compose.yml`.
- **Don't pass `-p`** (custom project name) — it would split your named
  volumes into a new namespace and force you to redo the first-boot
  chown.
