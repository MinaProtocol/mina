-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:eea4b6cd7ce0a92649bd8d8283c97a94c0cf70ce00fd63c3d08f1bfc15d2531d",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:73562fcc35dcabd342f66f1d69ae12704e92d69edc0b37e7c88b4d11bc623f23",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:73562fcc35dcabd342f66f1d69ae12704e92d69edc0b37e7c88b4d11bc623f23",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:73562fcc35dcabd342f66f1d69ae12704e92d69edc0b37e7c88b4d11bc623f23",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
