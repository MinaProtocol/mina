-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:0ef9bc261648a416066429afddf6fa93374744215c2a48b0b10776316716a2c0",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:66f6572428e3bd2fead59a92f77a754535db2967a443e46c8437b87f7f3fed17",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:186e4ca8d184466b316a98aaf9c757b28dcc93013459d574bbff25e043404e5e",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:6b6950f8bc92ac9e43e1545464042de20806d3941ca3c7d70ae542f4343b8bca",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
