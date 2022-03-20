-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:b88e942ec08683757de0d58f40bb5864c4196c969b13351fca14df336a02dd28",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:49ed40ca28fe73dfb33a311dee73e13548a692ade14d72e20e5f6c3f16ff9a28",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:05abb904ea1b6166847751c21ebdc89883e0d11515ed3e0ef5646e4bcd9340e4",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:3c5a525cf315219ca5d835b0cc8cf6cce7d8ac9a54a3a891f80e77af4b0a86de",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
