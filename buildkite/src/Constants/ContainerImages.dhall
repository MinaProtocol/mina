-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:9d807f6afd53dedb758c4214a1e67aa51198a407a5fce48c9eda446fb08f3c0a",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:c0f8e18e616862c32f9c070a1bc4024bdc9d4781d00106efe642006bc1ff9bbc",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:c0f8e18e616862c32f9c070a1bc4024bdc9d4781d00106efe642006bc1ff9bbc",
  minaToolchain         = "gcr.io/o1labs-192920/mina-toolchain@sha256:c0f8e18e616862c32f9c070a1bc4024bdc9d4781d00106efe642006bc1ff9bbc",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
