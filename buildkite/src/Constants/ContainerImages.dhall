-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:1acead196a01a0a28a70036ad17bb75385836c35999661c6d60b3c5e4a76d7b1",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:1acead196a01a0a28a70036ad17bb75385836c35999661c6d60b3c5e4a76d7b1",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:b01143a4addf95900dbd66ef0092ed017bb24d92ae5172e5977981cdfa246f05",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:a9f0d834355dcc197fe5eeeafe2ac4956071465d8800a9e470d4b45ca97c06af",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
