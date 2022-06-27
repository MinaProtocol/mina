-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:2263d65d2725a6a8d98f266df3c2573fa348a3d60d8a59bf8b29cceb5da97b2e",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:2263d65d2725a6a8d98f266df3c2573fa348a3d60d8a59bf8b29cceb5da97b2e",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:5c5616f717b71e73e9bede702261d4e2a62cecfbe72e462c9b9b6f92cc77312b",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:91b8d8f1906b86c3c11ad0773c1cc8ad9bb4253d16c9e371f6d9d30ce4cd07ec",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
