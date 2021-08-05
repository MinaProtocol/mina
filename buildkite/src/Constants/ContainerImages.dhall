-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:3c068932d3d1dfc4eb57206c4323794b887328345095801e28ef584ed4400969",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:5d9d583ddfded66faffad2d3cfdfe97acf5808ab8665adea4548c1c2ee789977",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
