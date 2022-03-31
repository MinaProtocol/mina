-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:575c4985e60392bd4de4c8fc393d26c21e16afa821c4cacd61d57edc5ae9745c",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:575c4985e60392bd4de4c8fc393d26c21e16afa821c4cacd61d57edc5ae9745c",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:47d2ba6bbe5ae1b69ccbfc56d053c113c1571bccfe0f77860040f2eb646686e6",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:e13cc3a7480b251afa818199d3d8cacfc9fe0002529dec03697c1d59d073722e",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
