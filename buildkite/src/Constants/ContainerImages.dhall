-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:74af314c348585d2aac91496cd37ca076b75b9059e399c5bed525690ba104f53",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:62ab1dd64fe532f6042d406dfce5e4774929af608f198bdd5a6a1584b0e3f2c8",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:01270ff28f56cd0be8049079c30449d1d94c6b9de32eef8ca75e4abcbe0b6cf8",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:ebf70399228f88c2f48d24a3d833173be6bf7040aaa6a018890f0c5030fa98e9",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
