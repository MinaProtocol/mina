-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:85bd2b9a477315cbf3442b4c0d0e304292eb0c70b3211d6fd640b63f05523ecb",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:b9469927f234e97d43a2c52ed8fdeee1d3440c66c83fc31d96f3d039f88a3e28",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:2dc81622c7cf0dca34e3a378c3910f10df4d001d0db1d086e1adef56b71b1757",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:147bad4fa52389ad44b78aba1a4a9d02ac62de465555e541be40834f9162b010",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
