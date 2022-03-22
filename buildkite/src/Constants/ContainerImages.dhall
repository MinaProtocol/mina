-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:e68fa0a3a27d4c64525371a87d750c720f1bdad032083ad0bf5ef5f3f0d9ed44",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:3d07e503c68c39e1b0681fb676bc3784fa82da6b22b3c98835097519fff7966e",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:893aead7d37c6b2ed3635adb6f99f1fee644cafbe0555f5bcfe687fb58ce5f62",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:d84706a48f50d844027c99146f5a114a638cf95117055b7818136bd74cc0c678",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
