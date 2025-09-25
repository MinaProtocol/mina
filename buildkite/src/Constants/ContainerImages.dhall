-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm = 
    "gcr.io/o1labs-192920/mina-toolchain@sha256:94cd586905888a36c2340abf92edae991ffce4006285e6ce034129d0e33ab396"
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:29998364d3130215501f085ba4d99a3fc2474d1975eef67b67af8b7e65e0f01f"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:be93e47598f24b2c364a52bb0546eecf60eab146084b2b6ab373bfb7ef066c0e"
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:4fe3d9a17af3177f1e4c549a0c014fc4ef376731848dbb6066cc2a7413b75c5a"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:29998364d3130215501f085ba4d99a3fc2474d1975eef67b67af8b7e65e0f01f"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
