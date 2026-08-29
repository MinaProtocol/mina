-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
-- NOTE: minaReleaseToolkit bundles the deb-toolkit binary and is published by
--       MinaProtocol/mina-release-toolkit. Pinned to a released version tag
--       (not a moving tag like :latest) for reproducible CI; bump it
--       deliberately when a newer toolkit is wanted.
-- NOTE: minaToolchain* pin the v0.16 opam stack, so they must stay on a sha
--       built from THIS branch: develop's pins carry v0.14 and will not build
--       here. Rebuild with !ci-toolchain-me, then bump the sha below to the one
--       it produced (all five images land on one sha). Do not reach for an
--       older toolchain sha instead: 3-toolchain curls mina-bench-upload by
--       version string with no checksum, so an image's behaviour depends on the
--       date it was built, and rebuilding is the only fix.
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
-- NOTE: postgres is the server every archive job runs against, through
--       RunWithPostgres. It was pinned to 12.4-alpine, which is end of life and
--       predates pg_backend_memory_contexts (PostgreSQL 14+), the view the
--       mina_caqti and archive memory benchmarks read. 17-alpine also matches
--       src/app/archive/docker-compose, so a dump taken from a production
--       archive restores into CI instead of failing on a version mismatch.
--       It is pulled from Docker Hub rather than the euro-docker-repo mirror
--       because no 14+ tag has been pushed there; mirror it and repoint this
--       constant if Docker Hub pull limits start to bite.
{ toolchainBase =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 = "docker.io/minaprotocol/mina-toolchain:44e9e82-bookworm-devnet"
    , arm64 =
        "docker.io/minaprotocol/mina-toolchain:44e9e82-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "docker.io/minaprotocol/mina-toolchain:44e9e82-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "docker.io/minaprotocol/mina-toolchain:44e9e82-noble-devnet"
, minaToolchainJammy.amd64 =
    "docker.io/minaprotocol/mina-toolchain:44e9e82-jammy-devnet"
, minaToolchain =
    "docker.io/minaprotocol/mina-toolchain:44e9e82-bullseye-devnet"
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
, postgres = "docker.io/postgres:17-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
, minaReleaseToolkit = "ghcr.io/minaprotocol/mina-release-toolkit:0.0.5"
}
