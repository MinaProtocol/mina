-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:0e8606612e438675277c1c8b9404e367ed102f0ef1bb887b19edecb2d2438379",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:054eccd7911287fb9f55c29495fd45edeb6d5aafbd9aac7fc7c6f924a06c0478",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:102053cf49e6c50af71ea20e5932a0af1d0e519077139af4b7bcab7f994e5f7d",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:102053cf49e6c50af71ea20e5932a0af1d0e519077139af4b7bcab7f994e5f7d",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:102053cf49e6c50af71ea20e5932a0af1d0e519077139af4b7bcab7f994e5f7d",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
