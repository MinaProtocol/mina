-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:1e3d51de5d06811f08ec8aee9058c8fdf5065e932580c0febb36b3060d499c9c",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:57089995c55815ceaa9c459af29152131c9360277f649ba6186b4fb4395cd106",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:78508e55d17020f893971f3e5d03645c3ce35644d545ec4584322b165bfbd751",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:d2ee78de661baa0f3082ae41cb6132a0e4c3a362253f57a6276e3b6c9fadad51",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
