-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:cd3f7f549fa485887f1897b402d2dcc0a9d28357b4b942156f16f5e35098d54a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:85f6ce38cec022670aa7285e15cb52e3459cb899f3fbe3506896791ac8fc3711",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:a30fb90fe732ac5f2443669e83fd43aacfa0991db50a08df267673c7590bb5f3",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:6363ac534fd927fb92cd8d19669ca8224f88d7a19d4c42f4947b421c9837a9c5",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
