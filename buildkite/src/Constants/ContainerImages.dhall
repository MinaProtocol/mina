-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:ff75d51b4b1fd0a91fa38445ed230a8012e2428b4fe695aa7ae14cd4f82c2017",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:1d1dccba8147d21ce2098cddf71ca57bdb10ffd6cf312464b1874cd1aad6bc5c",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:bb43a52f04941aefc1d1912027cd02972701233e7c1ea53ccaf704e5247bfac8",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:72fd8954d9f4f13e8596c3826c570e8fcd8473ec0091cbbfba17c9366e983e0b",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
