-- TODO: Automatically push, tag, and update images #4862

{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c108ac39dbd7a790a54fca94f70b8b666b52d2ab44f95a625e21e5b5ffffa4e3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:8a0e8cc15d6a6442a747f414c231bb08f4855c6ef77479cfa5e974c3e6da70ca",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
