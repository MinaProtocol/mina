-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:e4920236094ab23caad9ec9cda39babde6b777541db054e8138f71ac464f57b5",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:695396a777c13a7eb84e7ead702f07c78adfd64a6ca2304a1409ad2e26a38caa",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:de2ad3255acb939492fe9eb4daaac98831cabf7a4b7ef1fd1e7afceaa6b510a7",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:73562fcc35dcabd342f66f1d69ae12704e92d69edc0b37e7c88b4d11bc623f23",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:73562fcc35dcabd342f66f1d69ae12704e92d69edc0b37e7c88b4d11bc623f23",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
