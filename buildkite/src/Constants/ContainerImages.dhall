-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:275583e5cfe14022e346de7862148718633b6662c6b316957ddbb9bb9b200cc2"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:445ab21c8f86b4ef18b9d3631fbb7f1a5f90e0872d2552ec420745d894e58646"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:119f503a824e1405f22ff3e877fc789233bed076cb4466b44bb141bfc20bf5a5"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:407d1b0a2190c200344db67ca8409284bf28bd7fb021c2efa661be2b9c9f9705"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:e5da6e79298b87f051e0f2cb80a139ab398b005449f171155ed6f0d7c3036a2a"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:e3691c3adb95c64ac1b7436b8c27c915cc92c4c530670cc28cbddb57df6f4cce"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:119f503a824e1405f22ff3e877fc789233bed076cb4466b44bb141bfc20bf5a5"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
