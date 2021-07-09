-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "codaprotocol/mina-toolchain@sha256:61701a8c0382384f862888b7a0947f1209b5561af46dcca9d3ccd2aec04dea70",
  minaToolchainBuster = "codaprotocol/mina-toolchain@sha256:a8a19dfd03f2fec842daa5cb988389295a62ae5687d8509712dc23ac4b21728e",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
