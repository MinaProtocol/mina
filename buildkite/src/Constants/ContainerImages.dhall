-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchain = "codaprotocol/mina-toolchain@sha256:62655328be39f0ce8e1cfbc9eaee299f391b6375651b73b734e7a17944f58304",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
