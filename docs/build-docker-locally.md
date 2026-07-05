# Building a Mina Docker image locally

Build a Mina Docker image from a locally-built Debian package. Useful
when iterating on Dockerfile changes, packaging changes, or any flow
that needs a custom image without a CI round-trip.

## Prerequisites

- A locally-built `.deb` — see
  [build-debian-locally.md](./build-debian-locally.md).
- Docker (`docker buildx` for multiarch).

## Steps

`scripts/docker/build.sh` installs the mina packages directly from the
local filesystem — no apt repository is involved. It stages any `.deb`
files it finds in the `dockerfiles/` build context into
`dockerfiles/_debs/`, which the Dockerfiles `COPY` and install.

1. Copy your locally-built `.deb`(s) into the docker build context:

    ```sh
    cp _build/*.deb dockerfiles/
    ```

    > **Important:** the `.deb` files must be present in `dockerfiles/`
    > before the build; the staging step only picks up what is already
    > in the build context.

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
