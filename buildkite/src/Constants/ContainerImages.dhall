-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:8caae7c30784d415e0a65f3ad2b91646ef5b4dfe9b1e0b44b1d7ab6d9ca6196e",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:8c2436a4d92bef2409e6015f809c495e2d895ec35262f83d38ba5318745ceabd",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:105d03bfb68dd44f6b5ab7d4421a7cbb20862f5e295823d67d4c1a1f3428e8ac",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:27822043724b0cb2cd8c98aafdd686d28ca63c42feae347640a63d71c51370de",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
