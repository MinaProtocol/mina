-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:454107404a2e052618cf49550b447e5b89a0373ae7ec62e85b425e0cca7a1368",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d1176b5881a5911477e271d13c04225049f98d1a35b960942f7e811e3dc028d8",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:cc137283f4f2ec1f8d890e633f102fc5257fbccf953d525a2ee6f894594a019d",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:41595811bee45a4bd9d1fe7412f37b7ff1af2e4820d1375e620a66179678cb50",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
