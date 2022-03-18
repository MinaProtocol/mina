-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:355fa42286d07a042f670beba3c1f4da67099b79e104a117f2c8be062d618726",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:15b1c431e93ba3f7d7b4c6e070d53bbab667b5ccd60cc515a6a9d58f7a21d3c6",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:f3294b5803a87a5f305c279598fa8b9b90b4235e543cd316984bd59936e459e8",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:8b809e5f2fc19d13e0896927470909c11c4a559d88accc889de9f8bd18bda8af",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
