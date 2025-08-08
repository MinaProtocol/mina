-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:c6098cb128e137c38127ce335d93bdaf14d34454b31fdccde51862526e5fd8eb"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:32a0eb7159071752243201055e00aef16263aec518d1f161099ed508e810a0be"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:cd1382d8ee374953fcdd03cc8d2c2055af9c82ed3c533551ec095e644fe5a6ff"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:32a0eb7159071752243201055e00aef16263aec518d1f161099ed508e810a0be"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
