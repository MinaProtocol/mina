-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
-- NOTE: minaReleaseToolkit bundles the deb-toolkit binary and is published by
--       MinaProtocol/mina-release-toolkit. Pinned to a released version tag
--       (not a moving tag like :latest) for reproducible CI; bump it
--       deliberately when a newer toolkit is wanted.
-- NOTE: the mina-toolchain images are pinned to 33d64d5, the v0.16 toolchain
--       build (opam core v0.16 stack) produced by mina-toolchains-build for the
--       commit below this one, all five images (bookworm amd64+arm64, bullseye,
--       noble, jammy) on one sha. This supersedes develop's split b8d9c69
--       (amd64) / ffab0f8 (bookworm arm64) pinning, which carries the v0.14
--       opam stack and so cannot be used from this branch. develop has since
--       moved this pin again, to 4e95b64 -- still v0.14, so still unusable here.
--       Superseding the earlier cd3e35b pin from this branch: dockerfiles/
--       toolchain/3-toolchain installs mina-bench-upload by curl'ing a GitHub
--       release asset named only by MINA_RELEASE_TOOLKIT_VERSION, with no
--       checksum. The v0.0.4 asset was re-uploaded in place on 2026-08-03,
--       adding the --compare-branch flag that buildkite/scripts/bench/run.sh
--       now passes. cd3e35b was built 2026-07-29 and therefore contains the
--       pre-re-upload binary, which rejects that flag and fails every Perf job
--       with exit 2. Rebuilding is the only fix, since the version string does
--       not identify the artifact -- a toolchain image's behaviour depends on
--       the date it was built. Worth pinning that .deb by checksum separately.
-- NOTE: mina-toolchain and mina-base are published by DIFFERENT pipelines and
--       their hashes move independently. mina-toolchain comes from
--       mina-toolchains-build; mina-base from mina-docker-base-build
--       (!ci-docker-base-me). Bumping one is never a reason to bump the other.
-- NOTE: minaBase* are the published common base-deps images on docker.io. The tag
--       format matches build.sh's HASHTAG for service=mina-base: <githash>-<codename>-<network>.
--       These are frozen references, like minaToolchain*: the daemon/archive/hardfork
--       builds load them from the CI cache and build FROM them instead of re-running the
--       base-deps stage. Re-publish with !ci-docker-base-me (pipeline
--       mina-docker-base-build), then bump the short hash here to the one it produced.
--       A stale or unpublished hash is not fatal -- scripts/docker/build.sh falls back to
--       inlining the base-deps fragment when the image is not available locally -- so the
--       only cost of forgetting the bump is losing the reuse.
{ toolchainBase =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 = "docker.io/minaprotocol/mina-toolchain:33d64d5-bookworm-devnet"
    , arm64 =
        "docker.io/minaprotocol/mina-toolchain:33d64d5-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "docker.io/minaprotocol/mina-toolchain:33d64d5-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "docker.io/minaprotocol/mina-toolchain:33d64d5-noble-devnet"
, minaToolchainJammy.amd64 =
    "docker.io/minaprotocol/mina-toolchain:33d64d5-jammy-devnet"
, minaToolchain =
    "docker.io/minaprotocol/mina-toolchain:33d64d5-bullseye-devnet"
, minaBaseBookworm =
    { amd64 = "docker.io/minaprotocol/mina-base:86b89d0-bookworm-devnet"
    , arm64 = "docker.io/minaprotocol/mina-base:86b89d0-bookworm-devnet-arm64"
    }
, minaBaseBullseye.amd64 =
    "docker.io/minaprotocol/mina-base:86b89d0-bullseye-devnet"
, minaBaseFocal.amd64 = "docker.io/minaprotocol/mina-base:86b89d0-focal-devnet"
, minaBaseJammy.amd64 = "docker.io/minaprotocol/mina-base:86b89d0-jammy-devnet"
, minaBaseNoble.amd64 = "docker.io/minaprotocol/mina-base:86b89d0-noble-devnet"
, minaBase = "docker.io/minaprotocol/mina-base:86b89d0-bullseye-devnet"
, postgres =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/postgres:12.4-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
, minaReleaseToolkit = "ghcr.io/minaprotocol/mina-release-toolkit:0.0.5"
}
