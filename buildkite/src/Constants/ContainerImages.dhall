-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:528493fa68b055635e9db6fb30445b48a0eeac33c0a4ad9328a2777cf5bbaa6b",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:108d2e8a3f8b62dd709ebc355922cf73e374101dc582b2e709d23b813ab2327d",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:647f85811749aba5e9a292be809896fc75b442ab829d6fe108f4d003212cadf3",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:78f35639f558c122d3c57bf3991f5b3ec7b5c433b3d814fc7aeb5fe0a1bb8aab",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
