-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  codaToolchain = "codaprotocol/mina-toolchain@sha256:4dfca9088f0ffcde7dcfba7d816bb035e6be48e7014f256fbce8479a0be57a28",
  minaToolchain = "codaprotocol/mina-toolchain@sha256:4dfca9088f0ffcde7dcfba7d816bb035e6be48e7014f256fbce8479a0be57a28",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
