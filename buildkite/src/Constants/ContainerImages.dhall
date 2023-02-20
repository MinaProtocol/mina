-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:0327d1859c5b37ac9b2e59fc8d46dff77539c053ad7c14359314cd84bbec143a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:e1004682f055b2fb634b4fdaaacb4fcc6cf0a0c0c589664ecfc6c7ae1d4be46e",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:11ad02f3761873bc44d4b6988895bed9c0aa40307820bbeb73cf0426eef0d31c",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:11ad02f3761873bc44d4b6988895bed9c0aa40307820bbeb73cf0426eef0d31c",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:11ad02f3761873bc44d4b6988895bed9c0aa40307820bbeb73cf0426eef0d31c",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
