-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:08de11ec2f68be68b66214b90df8b9e9395805ef0eca8f6bc26507ad2beff1ca",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:52e3d98ed11bcb52c8d8b4f9e5aeef09d5cb0bbdf27a17e0dc6c3493391c49d8",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
