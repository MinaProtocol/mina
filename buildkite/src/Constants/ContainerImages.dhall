-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:43093d06be7981af3ab8fd496a15909d6ad60eef18a35c8beb3f0a4fa4df41df",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:43093d06be7981af3ab8fd496a15909d6ad60eef18a35c8beb3f0a4fa4df41df",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:5d59bb61c7942547e9faa5a68218090202e2472a8b7ace61c1ecaa2592ce0d04",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:3f2efab865ab63ae46af45916b145814b6118b75847a22ce505a50d016be3cff",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
