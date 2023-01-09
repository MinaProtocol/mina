-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:d78fc85d53f53df1102a4e719bfc16528ba56f40c6e43bddeac7e011a084095a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:c9c376d4a59c6b70098c8f60f24694690628fde9413d42987bf3f3c3fba0851e",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:639202a461cd2d9a4a4a4ac670ba53858112b587090f17a602cca74610793206",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:639202a461cd2d9a4a4a4ac670ba53858112b587090f17a602cca74610793206",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:639202a461cd2d9a4a4a4ac670ba53858112b587090f17a602cca74610793206",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
