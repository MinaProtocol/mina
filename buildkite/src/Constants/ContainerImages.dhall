-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
-- NOTE: minaReleaseToolkit bundles the deb-toolkit binary and is published by
--       MinaProtocol/mina-release-toolkit; `:latest` tracks its default branch,
--       so it carries the newest deb-toolkit each time that submodule is bumped.
{ toolchainBase =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 = "docker.io/minaprotocol/mina-toolchain:169fd52-bookworm-devnet"
    , arm64 =
        "docker.io/minaprotocol/mina-toolchain:169fd52-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "docker.io/minaprotocol/mina-toolchain:169fd52-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "docker.io/minaprotocol/mina-toolchain:169fd52-noble-devnet"
, minaToolchainJammy.amd64 =
    "docker.io/minaprotocol/mina-toolchain:169fd52-jammy-devnet"
, minaToolchain =
    "docker.io/minaprotocol/mina-toolchain:169fd52-bullseye-devnet"
, postgres =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/postgres:12.4-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
, minaReleaseToolkit = "ghcr.io/minaprotocol/mina-release-toolkit:latest"
}
