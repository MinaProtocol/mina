# Building a Debian package locally

You can build Mina's Debian packages locally — useful when iterating on
packaging changes or when you want to feed a local `.deb` into a
[local Docker build](./build-docker-locally.md).

## Prerequisites

- A working OCaml dev environment — see
  [setup-linux.md](./setup-linux.md), [setup-macos.md](./setup-macos.md),
  or [setup-docker.md](./setup-docker.md).
- The native build dependencies installed (`make build` should succeed).

## Steps

1. Build the binaries:

    ```sh
    make build
    ```

2. Build the Debian package. For example, mina-devnet on Ubuntu/Debian:

    ```sh
    ./scripts/debian/build.sh daemon_devnet
    ```

The `scripts/debian/build.sh` orchestrator builds individual packages by
name; see
[`scripts/debian/builder-helpers.sh`](../scripts/debian/builder-helpers.sh)
for the full list of supported package targets and the
`MINA_DEB_CODENAME` / `MINA_DEB_VERSION` / `DUNE_PROFILE` /
`MINA_DEB_RELEASE` environment variables that customize the build.

The package landing place defaults to `_build/`. That's also where
[`build-docker-locally.md`](./build-docker-locally.md) expects to find
the `.deb` when wiring a local Docker build to a local apt repo.
