-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:2557575bc2e17cab9799d99aebb3dd4971855c2e00f2e46272f15d4939e58bbe",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:b3a7739754188a0cd8b495f305b575c16e3bdde39192349d06993b288ddfb76f",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:1851d6da0d3ffb2d0a97921171ad70a3d287f8788b8c86b6e66e52862e8e081b",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:49a71cda9c556d5243eb16e24971faaa15e982cb8de3e997010a58bdf2559ebd",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
