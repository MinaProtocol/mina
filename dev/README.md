# Dev container — non-Nix Mina dev environment

This is the Docker-based development container, recommended when:

- You don't want to install Nix.
- Your host OS isn't supported by the native Linux/macOS guides.
- You want a build environment that pulls in the same toolchain CI uses.

Note: the *toolchain* (OCaml/opam/Rust/Go versions, system libraries) is the
same one CI uses, but the runtime is not a 1:1 mirror of CI — this container
boots as root and runs a small UID-remap entrypoint before dropping to
`opam` (see "How container UIDs are handled" below). Use it for builds and
quick iteration, not for reproducing CI-specific runtime behavior.

For other paths see the top-level [`README-dev.md`](../README-dev.md).

## Image source

The default image is pulled from
[`docker.io/minaprotocol/mina-toolchain`](https://hub.docker.com/r/minaprotocol/mina-toolchain/tags),
the public mirror of the Mina toolchain images. The tag pinned in
[`docker-compose.yml`](./docker-compose.yml) is a recent CI build; if it
ever returns `manifest unknown` (tags do age out), browse the link above
and pick another tag, then either edit `docker-compose.yml` or set
`MINA_TOOLCHAIN_IMAGE` for a one-off run:

```sh
export MINA_TOOLCHAIN_IMAGE=docker.io/minaprotocol/mina-toolchain:<tag>
make
```

You can also use this knob to switch to `bookworm`/`noble`/`focal` variants
without editing the file.

## Workflow

In one terminal, start the container:

```sh
make            # runs: docker compose up
```

In a second terminal, open a shell into it:

```sh
make ssh        # runs: docker exec -u opam -it -w /mina mina /bin/bash
```

Inside the container, set up the opam environment and build:

```sh
eval "$(opam config env)"
make build
```

When you change the toolchain image (or after a major OCaml/opam upgrade)
rebuild the volumes so caches don't get out of sync:

```sh
make rebuild    # runs: docker compose down --volumes && docker compose build --no-cache && docker compose up
```

> **Always invoke compose via `make` in this directory** (or with
> `docker compose -f dev/docker-compose.yml ...` from elsewhere). The
> bind-mount `../:/mina` and the entrypoint path `/mina/dev/dev-uid-fixup.sh`
> both assume the compose file lives at `<repo>/dev/docker-compose.yml`.
> Moving the file or running compose with a custom project name (`-p`)
> will break the entrypoint or split your named volumes off into a new
> project namespace.

## How container UIDs are handled

The toolchain image's `opam` user is UID 65533, but the source tree is
bind-mounted from the host into `/mina`, so any writes from inside the
container would land on the host with that UID — which is none of the
things your shell calls "yours". To avoid that, the `dev/` container uses a
small entrypoint ([`dev-uid-fixup.sh`](./dev-uid-fixup.sh)) that boots as
root, rewrites `opam`'s entry in `/etc/passwd`/`/etc/group` to match the
host's UID/GID, chowns the named volumes accordingly, then drops
privileges via `setpriv`. The host UID/GID are passed in by `dev/Makefile`
(`HOST_UID=$(id -u) HOST_GID=$(id -g)`), so `make` and `make ssh` are all
you need — no `sudo chown` step.

The script lives in this directory and is reached through the repo
bind-mount at `/mina/dev/dev-uid-fixup.sh` — no toolchain image rebuild
is required. CI continues to use the stock image (USER `opam`, no
entrypoint override) and the entrypoint is a transparent passthrough
when started as non-root.

> **Don't bypass `make`.** If you run `docker compose up` directly, the
> `HOST_UID`/`HOST_GID` env vars are unset and the entrypoint will refuse
> to start (rather than silently pick UID 1000 or worse, run as root and
> write root-owned files into your source tree). The Makefile sets these
> for you.

> **First-boot cost.** The first time you run `make` against fresh
> volumes, the entrypoint has to `chown -R /home/opam/.opam` (the opam
> switch inside the named volume), which can take ~1 minute on a populated
> toolchain. Subsequent boots skip this step entirely — the script checks
> the ownership of each top-level target and only recurses when it's
> out of sync.
