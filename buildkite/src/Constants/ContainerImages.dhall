-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-bookworm-testnet-generic"
    , arm64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-bookworm-testnet-generic-arm64"
    }
, minaToolchainBullseye =
    { amd64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-bullseye-testnet-generic"
    , arm64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-bullseye-testnet-generic-arm64"
    }
, minaToolchainNoble =
    { amd64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-noble-testnet-generic"
    , arm64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-noble-testnet-generic-arm64"
    }
, minaToolchainTrixie =
    { amd64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-trixie-testnet-generic"
    , arm64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-trixie-testnet-generic-arm64"
    }
, minaToolchainQuesting =
    { amd64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-questing-testnet-generic"
    , arm64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-questing-testnet-generic-arm64"
    }
, minaToolchainJammy.amd64 =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-jammy-testnet-generic"
, minaToolchain =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:9e6535f-trixie-testnet-generic"
, postgres =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/postgres:12.4-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
