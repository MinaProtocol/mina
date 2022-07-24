-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:d2b4e83f641b87b2aee4b981f374d524802a5535e5326ecea9ebe8ad2676faf3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:8701d3a8ba2c3cf56aa07196a68ac51687466ebace570a4e725bd38157a36e97",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:f887e30966bc2747302f1f7e0e3baa8e08aad4b387469f0212a4c3534260019b",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:16ebfd20c2f22cb99dde2afd253daa5c91d254f34316943a54e09c1caedfbe55",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
