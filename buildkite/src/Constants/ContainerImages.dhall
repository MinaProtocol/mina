-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:fc192cbc44f6a5e86316d467df46a4fc8257196cfe9149ab64e47ed698f1f201",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:fc192cbc44f6a5e86316d467df46a4fc8257196cfe9149ab64e47ed698f1f201",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:84f7217a3fe224d63639e2c5ff99a945d5913fd82c5a5f87f6a8e40c5a73636a",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:3e5a9af4d439c026d7bb05d3928e029b5a6ffd8248da6dfb095f49b13a6c5043",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
