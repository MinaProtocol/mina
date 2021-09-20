-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:645b709a7ea49e62b7da87243f3126c7d157d37dbf5d70750073b4a47cb4b342",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:cfd0927cca88a071a7adc17accd9d63411b1ec3c51b918ed8715c6a1c61f1a58",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
