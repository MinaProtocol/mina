-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:1b901f35d726af1e30fba4a1492b11f8bab87c8627f8f56e264fd119d7840425",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d4a56f985616507ff85ce93779c7b24c4927ae963ac1133e5248065c5d742870",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c10913d9a48ad9b3c729fb4a53874e5583bf9c17b0d9a34510cbd2526b81f12c",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:e3bf51b67b00b0e4d700ae95492437790e4f8651b7077dd244115bf9312f9561",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
