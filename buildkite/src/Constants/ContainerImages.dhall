-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "minaprotocol/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:f92c6f2dde5d38f0c245e58c3c462fd17d311cf1020275e0a935175377c9bb82"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:87aacba132ae682e82f7f3edac7764a3fef0613e64e7f219e6f1085171643b91"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:f78963ea2e89e855f5e3b8de614a061e4c1ffc6c1c5c0b68d6c9e6329bf581c9"
, minaToolchainNoble =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:967431a014fbdf0d9d0628c37536575c9d018a7cbf91fab0c8da178127b74093"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:e260ad8dc428e33aa677db1f81cc612f47922a754deee3706d96a62dae9d82dc"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:e404a57828330a6f9ff673c6e76ebd1d2e9175c1b4b594399dd3b238ddf960a1"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:f78963ea2e89e855f5e3b8de614a061e4c1ffc6c1c5c0b68d6c9e6329bf581c9"
, postgres =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/postgres:12.4-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
