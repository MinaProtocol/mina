-- TODO: Automatically push, tag, and update images #4862
-- TODO: Make focal image distinct from Buster
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:ca6ac234bf3ac62cda3fd396864053a980f21c4b83384904827375a28ac65bd3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:383de47004e7bb16ba7d166e3c82dc5087e014b766d64a2a4f92dbbefc7af4b6",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:4c6ce8e3a1789ba0b9ca5f5b7e377a2ae113252d6f482bed7b157c8e82aeca43",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
