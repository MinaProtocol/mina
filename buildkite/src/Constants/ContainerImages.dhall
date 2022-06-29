-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:5546fea89cd065db2045bd854369e729bf5bfbc38d488edd39768a501788fbbb",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:dd1985ba8c606db91bdf251b3a60d314ce23ee6acf8f4c169fe062c7ab5360ce",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:18694394f42cb4745f87848ff84e3ca2fedd9694992dd73d7a8e696ea8eb2def",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:8ae2154d7ddd8517769ac547ddbcefd8d0cd634b4d1fb39a372fe9376dd8b627",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
