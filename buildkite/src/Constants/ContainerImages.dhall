-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "codaprotocol/mina-toolchain@sha256:61701a8c0382384f862888b7a0947f1209b5561af46dcca9d3ccd2aec04dea70",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:7ef56c621e121edddbe951ffe55a3a3f40140c6b865c3f916eed7b9bd330021f",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
