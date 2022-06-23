-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:b363dd3a94a52710704a5e5ceb67e7969d0728b1ca0062e6d552539bdfb99fe7",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:b363dd3a94a52710704a5e5ceb67e7969d0728b1ca0062e6d552539bdfb99fe7",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:55741aa88136af2885e0282560d7507c6e214f343ffefcd906c9e83f4c4de8a1",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:8323a3c9f361896076f1c02842c895357b298abfa13b0d7f07fe45a6707e7a01",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
