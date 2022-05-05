-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:88bc6b7fdae563998c88849f8c5133f3dec51dd800f5ea7c6002bc92f7081510",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:c40016dc90b2293b5ec12e24aeea38e19806844bbf5c25661dcdb4049ccb71f7",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:8ce948d43b35ec5559cd0a389ed7e602b8bfc88c598b97b68fca16d586bc93c2",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:0ab44a74ff4331aeb84a352b5d5f4ab7fcc10ebfeb1eba9259201435b1cc7860",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
