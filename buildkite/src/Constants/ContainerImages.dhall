-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:55a2fa7edd8d89f4627e4a84956004b375294379611035f2834aef00b6a3b6ba",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:abd774ddf4810a97427991992d6ba588fc677cc4416fd00e095c60f7efda6db4",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:045148c3005a7ee50c6895efbd40d45c24b74551d8e60a4af12a2fc0d59b46a8",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:5ed1d97522ab5ce173022752ef293386d67c8a6bcdf7882bf2064292a703ab9e",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
