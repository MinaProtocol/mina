-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
-- NOTE: minaReleaseToolkit bundles the deb-toolkit binary and is published by
--       MinaProtocol/mina-release-toolkit. Pinned to a released version tag
--       (not a moving tag like :latest) for reproducible CI; bump it
--       deliberately when a newer toolkit is wanted.
-- NOTE: the amd64 mina-toolchain images are on b8d9c69 (carries the
--       mina-bench-upload benchmark uploader), while bookworm arm64 stays on
--       ffab0f8. The mina-bench-upload install is amd64-only, so the arm64
--       image content is identical either way; ffab0f8 is already published
--       and the arm64 toolchain build under QEMU is flaky, so there is nothing
--       to gain from rebuilding it. Reunify the sha on the next full toolchain
--       bump.
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
    { amd64 = "docker.io/minaprotocol/mina-toolchain:b8d9c69-bookworm-devnet"
    , arm64 =
        "docker.io/minaprotocol/mina-toolchain:ffab0f8-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "docker.io/minaprotocol/mina-toolchain:b8d9c69-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "docker.io/minaprotocol/mina-toolchain:b8d9c69-noble-devnet"
, minaToolchainJammy.amd64 =
    "docker.io/minaprotocol/mina-toolchain:b8d9c69-jammy-devnet"
, minaToolchain =
    "docker.io/minaprotocol/mina-toolchain:b8d9c69-bullseye-devnet"
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
, minaReleaseToolkit = "ghcr.io/minaprotocol/mina-release-toolkit:0.0.3"
}
