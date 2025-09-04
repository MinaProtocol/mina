-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:37356ad5097ad8e91adf025ef7cbabc79b26efa69c4bd9326b709e3573ddce17"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:2e75b9fe032d0babcdb0d477004a670b3452918f641ea6104067f66bce1fe7a5"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:3d07c8a436597c2b79de49cd8bd96c23352e853062340a4f3bb665de480f873c"
, minaToolchainJammy =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a87bb215c4cda83fa6fe5208e0cab397f3686c4308d8f9cfb8ab3f7821230627"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:b1f29443c39c8421de433a02184a3e8fc993239e49888851e166d4009ff0c248"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
