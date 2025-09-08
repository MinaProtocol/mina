-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:38e5e769f856531fafe37da39aa21d1f9d7d770d4d45ab2d38a6bed553830260"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:e9e5e0cf840de54b1d096fe4d0a128b169bba5ba753e902fdcec9d4bc27094a6"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a2a91ff49a7f8f2e7dca02cca629930e502b79ec76a77b1acd33ae028f9f52eb"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:626a709c5ada4234436badae48173053882a9fdb2036d75ffcf65ac76f572669"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:92046c8910bb2e1d8487822f7e358637da32a50c0f1f4eba5186bb89509ddcdc"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:62bfc14a6a92714d7be7dce4a10927bc5e74351e86e483dc312ee19fc3566266"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a2a91ff49a7f8f2e7dca02cca629930e502b79ec76a77b1acd33ae028f9f52eb"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
