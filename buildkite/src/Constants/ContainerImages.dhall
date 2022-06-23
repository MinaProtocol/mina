-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:494fd6d80071b283a539d66eee0798797fcf2059b6e61a1a0f3e4b0560a15b9c",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:494fd6d80071b283a539d66eee0798797fcf2059b6e61a1a0f3e4b0560a15b9c",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:265338f1e796f8b4518340fd7e92b90a1fabb5286f0664e4d73aef21ac2f4b0d",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:649e697ad1428c898f16c9d5c937216da6d4a5c856073e54d0667c2ce82323d6",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
