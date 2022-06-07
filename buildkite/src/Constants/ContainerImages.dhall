-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:6722454fcebb2f69f8f54d60b59e9f1ea93b5d980e84a5cae5e3fdfbab2f1466",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:0204eb17cd4bd2ff57455d6e68236ad0794e8c347f0444f6e3deae15d8826c9d",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:d8b05b3824246cc34a342bbee5102e5f461316758309e81f0f60139010bf9e1f",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:b1cff74205f39c44e524d46b54e1c5f990cc481e54f2b835a0d04765223baa6c",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
