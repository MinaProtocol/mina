-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:1c95b5b4016db7bcf7b4c546fd36e162f90baff0babc0ac3287df19cb33f72db",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:abe7bae009da64f51c9bcce879208c4e1f3faabc3e5fae737c51bf33a6def95a",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:36455abc3733cc5db9e4bd3039afcece958bc363f049ec155044f30e08b49862",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:7f8725ccc04ddeff0ee991094e185c3fa501c46fe2b1a92a25a17d9313b948e0",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
