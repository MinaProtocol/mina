-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:2fb59f81df0546e2b406b871b878eae3dd3a05f2b5e214b831eb484b9fd445c8",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:2a5805c7d62fe150ef8552024c94f0e6d49b35688e3c994f1ca93ffb4a068031",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:20c006404f34fef712c71f7a7bcfc4c46d5c14dc48f6d33783ebe5839f9afe80",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:0a9a91a6e74bd2ae4a9a6bb4394ecf244d0ff38d18889fd21018556a2c322ae2",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
