-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c2e6c876b8500ae230652791fe93e69608bb138580cd4edd3323074483a99532",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:de0f5e1f14a999585d821952780baddf847f9ccd1c769cdfdf245a7c144109c9",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:5e137e6e9c0caebec4a969d25daa3c82b0d378da2b70af3a164265a8a223df40",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:1b0725571c5f01a0be382a2174201f2d91623c39a9bceae37e0dd7d060ce1a98",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
