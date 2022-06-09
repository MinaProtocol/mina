-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:0babc62acc5d6ba2ff0a5dff59daec2745200d9cca9fd69403f1bf3438a5117f",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:0babc62acc5d6ba2ff0a5dff59daec2745200d9cca9fd69403f1bf3438a5117f",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:21afdc743add499406b8bf8bcf50fc1ceee1b546c87946fdc15bbe46367636c0",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:633d3cfc29804462ae116c2206c8b6926e460ea9e5aa220d5b2966632384a9e6",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
