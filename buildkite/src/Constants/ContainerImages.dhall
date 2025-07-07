-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:26ec8e0b3427d029b7c0ac7c59ee424b3aaf4ad68ba9369ed09848ae29ac756b"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:f37eb91ffc19f4a9b9d37155a0f3aa694110098c39efc07107445a55178f37b5"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:53b9f6a4dd271bce20cdef000a4db2741f173ffefd782770db2414910d6a7f48"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:f37eb91ffc19f4a9b9d37155a0f3aa694110098c39efc07107445a55178f37b5"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
