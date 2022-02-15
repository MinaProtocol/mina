-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:b4e2781e58ddfce2949b3f5a702e1714e9630114869a4e3dd6c9191f4b1a65dc",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:a7bb2d2a287af2ce3e371a4856ffbd20fc13aa69a4d9308c2dd20729c0662663",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:44e46fd7fb38f43ab5399f471233fce8d483ec6ee59259ad44771440d67a04e2",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:926f011b0ebb1b0ee3f126b92c2f66544309209f1d35f154ca798d968ff8e345",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
