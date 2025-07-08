-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:809e6b4af19a962a6a158b835007e24c45118d0d3da59a8b8013094c774f8279"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:7a9cd3e3eeb30ef2a7cad1737bcf7382c425275dc7664c86c9714ab4fe7bd091"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:56455a3fa1a3b575b511e89aba88f7f8374ecc7b20ca04f26e035b17b63356e9"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:7a9cd3e3eeb30ef2a7cad1737bcf7382c425275dc7664c86c9714ab4fe7bd091"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
