-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:19b4e6e1c7bf76ad9f37d080744b8e4642e2e5aa111feeb80fab82697f81b9d8",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:85cd8e890cda3b6c4f294a5c67a3a71fbd1e593a25ac5b3226c29c9a95ce38a6",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:f292e868956ca0e8ca3cc1c7543398e4b9696bdfa502497304259dacc4f5725c",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
