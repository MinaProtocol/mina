-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:ae3eb28738698e7331c4f3650ba120a3c24ab097715e6d3dfc2acd4d36f147cf",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:20916cc7ba0de85392bc6aeb8a507219f6506d90807fc66a0a2da49bf728c6ba",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:8b195eec6b7f92be2b45a11d503b5a1e986e369828c8077dee987fbbd1a1f456",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:c4f624708c6e713bed829bc843cdf531bbd7af1752969be5b48f0a5a9db5aa24",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
