-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:b85a056a92e48716fd2c6fe9daad50ee4c2f3530e7baa73a41957d2630db77ff",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:0f65c72521dd3213ed597d597bd59f2712455d335361d3261e86b8ad654f07e2",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:23558dab1d1860e7b01ab7aeba457d2483b00bcd041d3dc827000f3b26b651d0",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:23558dab1d1860e7b01ab7aeba457d2483b00bcd041d3dc827000f3b26b651d0",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:23558dab1d1860e7b01ab7aeba457d2483b00bcd041d3dc827000f3b26b651d0",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
