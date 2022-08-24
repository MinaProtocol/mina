-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:36ed8f899635354fadf05a8504c054f4ca2a71950164c4aa8bea31f4f760afdb",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:6de0eb2aded56dd3f1c21df727e2d1ea53194095c0a45b025eaa93cc74166185",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:77444cd510dc40efd8c62e5c1a53485a05f3e42d4f883d2cfe74158847763af2",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:0b6167a26de97ca715bdcc4cbe759e3117d2fd0c0f5e03038a382fc25c60afcb",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
