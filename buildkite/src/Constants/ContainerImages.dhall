-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:31bb3844f9b83f8bf95a4ec04becf1a88a67c99a6bec1828d7bd476a3f95d0b3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:3348985dd0ce8e752375d379975b661076ac8eb31eda1e23c137a05ebe4715bb",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:9c4062e76fcd910ad60d3f1f58e2395f6a5e70f16fbef422442aedb70112ac73",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:9c4062e76fcd910ad60d3f1f58e2395f6a5e70f16fbef422442aedb70112ac73",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "nixos/nix"
}
