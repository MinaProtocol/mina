-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:ed8d107ec52af0e33307105bea67567eded51c4db06956af389bbdf305c91b8a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:5efd404184a292826ec1130919a7df46c97d2fd756fffefca112a08683af0518",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:99a98309104230dbaad6074e0c226e78f8b4c973edd5fed624f3817a24b56a62",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:75a0f3f3fb870505ce30e8b8a0929f9f1c60e554869a72a42f9d5fb508e7bac5",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
