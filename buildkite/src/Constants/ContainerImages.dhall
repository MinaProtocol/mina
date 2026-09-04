-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain defaults to minaToolchainBullseye. Bullseye also builds
--       Ubuntu Focal debs in CI; bookworm builds Jammy debs.
-- NOTE: minaToolchain* and minaBase* are frozen tags, <githash>-<codename>-<network>,
--       kept on one sha. Republish with !ci-toolchain-me / !ci-docker-base-me,
--       then bump the sha here to the one that build produced. A stale minaBase*
--       only costs layer reuse (build.sh re-inlines the base-deps stage), but do
--       not reach for an OLDER minaToolchain* sha: 3-toolchain curls
--       mina-bench-upload by version with no checksum, so rebuilding is the fix.
-- NOTE: minaReleaseToolkit is pinned to a release tag, not :latest, for
--       reproducible CI; bump it deliberately.
{ toolchainBase =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 = "docker.io/minaprotocol/mina-toolchain:157199e-bookworm-devnet"
    , arm64 =
        "docker.io/minaprotocol/mina-toolchain:157199e-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "docker.io/minaprotocol/mina-toolchain:157199e-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "docker.io/minaprotocol/mina-toolchain:157199e-noble-devnet"
, minaToolchainJammy.amd64 =
    "docker.io/minaprotocol/mina-toolchain:157199e-jammy-devnet"
, minaToolchainTrixie.amd64 =
    "docker.io/minaprotocol/mina-toolchain:157199e-trixie-devnet"
, minaToolchain =
    "docker.io/minaprotocol/mina-toolchain:157199e-bullseye-devnet"
, minaBaseBookworm =
    { amd64 = "docker.io/minaprotocol/mina-base:157199e-bookworm-devnet"
    , arm64 = "docker.io/minaprotocol/mina-base:157199e-bookworm-devnet-arm64"
    }
, minaBaseBullseye.amd64 =
    "docker.io/minaprotocol/mina-base:157199e-bullseye-devnet"
, minaBaseFocal.amd64 = "docker.io/minaprotocol/mina-base:157199e-focal-devnet"
, minaBaseJammy.amd64 = "docker.io/minaprotocol/mina-base:157199e-jammy-devnet"
, minaBaseNoble.amd64 = "docker.io/minaprotocol/mina-base:157199e-noble-devnet"
, minaBaseTrixie.amd64 =
    "docker.io/minaprotocol/mina-base:157199e-trixie-devnet"
, minaBase = "docker.io/minaprotocol/mina-base:157199e-bullseye-devnet"
, postgres =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/postgres:12.4-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
, minaReleaseToolkit = "ghcr.io/minaprotocol/mina-release-toolkit:0.0.5"
}
