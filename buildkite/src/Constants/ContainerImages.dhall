-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:af2a09f7a464d3f08f805a397439e9b7b3052069e4c20eda715313fcea4a77b6",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:b1f4b28283673ce38dbf05982ccaa00a0e13968101267118e809d6bb57044c0c",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:d46e66004e41556d41d4a0596257b67507614186940fb986667d1832b259fc23",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:490e38f7ef723f5bbe7b1a5fb8be967040aafff2c49b42e346c1bb6841b41c0d",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
