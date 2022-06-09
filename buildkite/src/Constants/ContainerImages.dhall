-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:df7043f51c884dfb39caf8a40e6569e30bfdd4fa0636e19806f47d079b63d074",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:df7043f51c884dfb39caf8a40e6569e30bfdd4fa0636e19806f47d079b63d074",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:ac1b2446d9115587b28d7e42f8863f2fd3891d27d5fb2ff7b98bbe4e27c5f145",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:ec496e26be7430bbbf02327bdc74e2e247c1ceae894c7e31d77c238cdb1d4072",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
