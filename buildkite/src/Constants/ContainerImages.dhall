-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:73d1775b0277dc4f0763a0acdd9b054982ebd1b6b061c883a5eca8410e166801",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:57e14a551a2773f28cf53907d09753b904deede806843a6873d6dfc5ab51b8d6",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:73d1775b0277dc4f0763a0acdd9b054982ebd1b6b061c883a5eca8410e166801",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:73d1775b0277dc4f0763a0acdd9b054982ebd1b6b061c883a5eca8410e166801",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:73d1775b0277dc4f0763a0acdd9b054982ebd1b6b061c883a5eca8410e166801",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
