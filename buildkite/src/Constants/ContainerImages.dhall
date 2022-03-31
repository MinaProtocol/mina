-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c91f9cb1d6625de8b5991c98e1758f07a2ff644fde1904d975dff2829c4f525a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:66a00e27d882cfac6309d74e2dc4e239e72079d1ac058d4d363955c667a6d6f5",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:7eb1de4ec8d4eaffeda724bd70712745466395501f6572645344d3f83349c814",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
