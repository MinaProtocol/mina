-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:e20e7b29210815e18660541cdd26a1d248a06d28e53b27075e5c8712a5f11df4",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:cdd50c2e29f72b9b1b177605094c02a27490f1dd8e68f0ebf8a4f66a4d46f18b",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:bf21af27ff31a85e296f8d16c37ce3f78bb8bd6fa355942881f2542bb1a6ec89",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:ca2afa4a54ee3849f26a2e5edc34366e7a66bfa377e91adaf93b2ccff95c52ca",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
