-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:c19f37f532e4bbee1a05244119839bf72886421804aa0591c1324f061c99ed98"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:e0359f72210b66bd541465fde8bc87535d93b70a5ac1a92c6d9f2e56e9c6dde6"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:0a23855e267ebfc7848454d33f8043a4a343539d9365bfdb12146831d2e9c754"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:e0359f72210b66bd541465fde8bc87535d93b70a5ac1a92c6d9f2e56e9c6dde6"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
