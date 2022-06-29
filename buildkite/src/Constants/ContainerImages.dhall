-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:9f4049bff1818ed373e1ee8dccdf35fc73d1c980a2a4e30947bc10df6239900f",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:0853899f33572b847bb0187340493a20e207ba7e11eedab860185bdc4dcf082d",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:ac1b9efea7c0055fe13393a929eb261bc9e95d1f3df59f15c21003407520ccc4",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:b4726316d1f1ea931dfd7fc66d7658239476606010d620a8260250ac24cfc28c",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
