-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:4bba314d04bb54b92a7c9bcd20aa2e00c73016de73c25e358dcdbc0d3152a522",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:1d1dccba8147d21ce2098cddf71ca57bdb10ffd6cf312464b1874cd1aad6bc5c",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:ccde2464d41c43341b31fcf1287d7170856e724c50192fd99bca6b2f6e8ff9fc",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:3c96f4cf9d87c45c78860afa7d22a44271a94499623fbb1aeecdd099d4586f87",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
