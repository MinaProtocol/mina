# Building a Mina Docker image locally

Build a Mina Docker image from a locally-built Debian package. Useful
when iterating on Dockerfile changes, packaging changes, or any flow
that needs a custom image without a CI round-trip.

## Prerequisites

- A locally-built `.deb` — see
  [build-debian-locally.md](./build-debian-locally.md).
- The [`aptly`](https://www.aptly.info/) tool installed.
- Docker (`docker buildx` for multiarch).

## Steps

1. Start a local Debian repository on top of `_build/`:

    ```sh
    ./scripts/debian/aptly.sh start -b -c focal -d _build/ -m unstable -l -p 8081
    ```

    > **Important:** the `.deb` files must be in `_build/` (the path
    > passed via `-d`).

2. Build the Docker image:

    ```sh
    ./scripts/docker/build.sh \
      --service mina-daemon \
      -v 3.0.0-dkijania-local-debian-build-a099fc7 \
      --network devnet \
      --deb-codename focal \
      --deb-version 3.0.0-dkijania-local-debian-build-a099fc7
    ```

    Where:

    | Flag | Meaning |
    |---|---|
    | `-v` | Base Docker tag |
    | `--deb-codename` | Input Debian codename (`bullseye`, `bookworm`, `focal`, `jammy`, `noble`) |
    | `--deb-version` | Version of the Debian package the resulting image will host |
    | `--network` | Network profile for the daemon (`devnet`, `mainnet`, etc.) |
    | `--service` | Service image to build (`mina-daemon`, `mina-archive`, …) |

See [`scripts/docker/build.sh`](../scripts/docker/build.sh) and
[`scripts/docker/helper.sh`](../scripts/docker/helper.sh) for the full
flag set and image conventions.
