-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:844efb68c890524938b3cac30b2f41a43cb0a24f1eed6d5a9b5912a72cf4ad71"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:bbeaa957443357adf132951fe780600821d817c40cfbc6c71a04eba5e97df97f"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:9eb216d62a319ba9ef9670e7b753d76f24db8f86ad638992e5095839348b401a"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:bbeaa957443357adf132951fe780600821d817c40cfbc6c71a04eba5e97df97f"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
