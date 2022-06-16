-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:553d83b6fae506693a4e2445e61ded253e9de2fa9b8e67753bb23e795831c82c",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:553d83b6fae506693a4e2445e61ded253e9de2fa9b8e67753bb23e795831c82c",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:2c4ec931d7ccb1cb50121ee79b0191d7294f945ac95207e787ab4337eeb817dd",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:d41b242d7d407fa09b67cc6998f430b69804981751c5c1ef16d8193bee12a168",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
