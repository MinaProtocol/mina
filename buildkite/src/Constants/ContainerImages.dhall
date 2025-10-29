-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:af79d53279cd58d8c3b013e8c438b479d9067bcdbe8cb32ced74a156bba78e15"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:a073bd8a471d03216bc1080ef3fda7a414bac786e6b18021241983194f118624"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:24c1a641f0d55167006581fd70a013cd90f8a89f3424650ace7ba4210b6825b6"
, minaToolchainNoble =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:37c475d7bcb412fa210e7f3cc82e48e2b78de7a5d770bee7a38cc35577890efc"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:b5ed1feaf22bf72a68db0b9289f578fee511474412a36891e97afb5f5c2a8bd5"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:ff7224ded94d4b41049c1c2f5b3df0820cf81d435291b116628a6c582e9c5c2b"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:24c1a641f0d55167006581fd70a013cd90f8a89f3424650ace7ba4210b6825b6"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
