-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:1c585094900f574d7d63bf1f87dc3c23c961b9ecd00d2f9765a9d2e4b06fbd21",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:4ee914f12545d98a948ebf7f1124e184674b60a711891602c9e0d380f7d2cb5d",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:1ac7d98fdf6e48da9b3ab2056d5f16eaa587db44670b7c30c48683802b6a1be1",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:9d4ce90350f02c23a71f422e7db36e2010f6e1c04a8c25aec11f142cf5297c02",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
