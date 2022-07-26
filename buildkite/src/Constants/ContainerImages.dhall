-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:70252768e34ea1e3ffb13e356763b86448744c2b8472afd998b869083f616a06",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:c6f37dc51bca7108086807399453cd9de7f930be5e6242806bf4799d874da436",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:ceadaf4992ab8e8923283d349d058f1b6e722dbc025a55c6117f05102e706d04",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:024c20d364fc15d0975dce121ad4e3c7da274c473a1552b0afe217210b9ba35b",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
