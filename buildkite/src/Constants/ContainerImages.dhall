-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  codaToolchain = "codaprotocol/mina-toolchain@sha256:d9e873a2ffd060d049251c276c0a6982d281f81541da306fec5711fc008afc58",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
