-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBookworm
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "docker.io/minaprotocol/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bookworm-devnet"
    , arm64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-noble-devnet"
, minaToolchainJammy.amd64 =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-jammy-devnet"
, minaToolchain =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bookworm-devnet"
, postgres = "docker.io/library/postgres:12.4-alpine"
, xrefcheck = "docker.io/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
