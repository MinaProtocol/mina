-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:881369ff5bfb2aaa034142da549123b1708c84db33dd78559445497ce36788c8",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:87c5eeefbc03cb1369195eb154dc6e867d8fc759971ce2b9f53901b781aeebdd",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:4d20ed80b7a7bf03dc5e26a32569696ec89980e18095316b149d2106015f2d27",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:5a6267d6b8d81e05e4d8180cc08328cd981be91f9c81f179469ed8f5557b01f7",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
