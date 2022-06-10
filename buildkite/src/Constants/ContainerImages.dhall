-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:64a5b06226c02eb33acf20571cf1ffde0fc39525304a173d0ce92c0fe1c74be8",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:6b95a4de88fb80fc442aebf83d41241d7142e0da9dc676b9152b7433b5a2b0d5",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:fa1c313451657a753ec63f38935e27df14cf235a90579a96fcf2db883b6f1f90",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:8d5631e806f848cf6818424897a3a2246740d83b25eeafa51c85b6e4438c095c",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
