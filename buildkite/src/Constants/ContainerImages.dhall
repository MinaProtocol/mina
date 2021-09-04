-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:beaf3b311c150244f590b34540a84ce54ecd9cca7eb930dc90e4880d1589f284",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:02b5284212156020d3a67f433fa4def6aa25cfe0759fb872ebd56870dc394bc0",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
