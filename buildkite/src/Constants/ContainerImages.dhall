-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:37d8b7f1a96fda041c4d27d01e35d808756d763a577927a9b17120377d1cbc8e",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:37d8b7f1a96fda041c4d27d01e35d808756d763a577927a9b17120377d1cbc8e",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:74c495dc1fb2d92bb070228f49862a7df2b3c9e7c4acc91336ae45693b18c277",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:7b87afb98d55233476c59ff43e5eaf33f4df0d4be445125fe740dcfd0f7ae58f",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
