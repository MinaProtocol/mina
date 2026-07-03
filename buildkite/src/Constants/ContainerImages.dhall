-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
-- NOTE: minaReleaseToolkit bundles the deb-toolkit binary and is published by
--       MinaProtocol/mina-release-toolkit. Pinned to a released version tag
--       (not a moving tag like :latest) for reproducible CI; bump it
--       deliberately when a newer toolkit is wanted.
-- NOTE: the amd64 mina-toolchain images are on d906afe (adds mina-bench-upload
--       for benchmark uploads), while bookworm arm64 stays on ffab0f8. The
--       mina-bench-upload install is amd64-only, so the arm64 image content is
--       identical either way; ffab0f8 is already published and the arm64
--       toolchain build under QEMU is flaky, so there is nothing to gain from
--       rebuilding it. Reunify the sha on the next full toolchain bump.
-- NOTE: minaBase* are the published common base-deps images on docker.io. The tag
--       format matches build.sh's HASHTAG for service=mina-base: <githash>-<codename>-<network>.
--       The 169fd52 short-hash placeholder is updated whenever the base image is re-published.
{ toolchainBase =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 = "docker.io/minaprotocol/mina-toolchain:d906afe-bookworm-devnet"
    , arm64 =
        "docker.io/minaprotocol/mina-toolchain:ffab0f8-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "docker.io/minaprotocol/mina-toolchain:d906afe-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "docker.io/minaprotocol/mina-toolchain:d906afe-noble-devnet"
, minaToolchainJammy.amd64 =
    "docker.io/minaprotocol/mina-toolchain:d906afe-jammy-devnet"
, minaToolchain =
    "docker.io/minaprotocol/mina-toolchain:d906afe-bullseye-devnet"
, minaBaseBookworm =
    { amd64 = "docker.io/minaprotocol/mina-base:169fd52-bookworm-devnet"
    , arm64 = "docker.io/minaprotocol/mina-base:169fd52-bookworm-devnet-arm64"
    }
, minaBaseBullseye.amd64 =
    "docker.io/minaprotocol/mina-base:169fd52-bullseye-devnet"
, minaBaseFocal.amd64 = "docker.io/minaprotocol/mina-base:169fd52-focal-devnet"
, minaBaseJammy.amd64 = "docker.io/minaprotocol/mina-base:169fd52-jammy-devnet"
, minaBaseNoble.amd64 = "docker.io/minaprotocol/mina-base:169fd52-noble-devnet"
, minaBase = "docker.io/minaprotocol/mina-base:169fd52-bullseye-devnet"
, postgres =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/postgres:12.4-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
, minaReleaseToolkit = "ghcr.io/minaprotocol/mina-release-toolkit:0.0.3"
}
