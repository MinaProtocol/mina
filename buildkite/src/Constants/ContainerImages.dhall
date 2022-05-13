-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:ec08248fa3bbb527cd4609747c710a456d9a3531e74952ad486b09d588134534",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:ec08248fa3bbb527cd4609747c710a456d9a3531e74952ad486b09d588134534",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:46c05462bbe5192a4713d13233faefc0d08bd24ccc15dad4e1f0cce7971aa15f",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:6efedfa6208c562c12442df15defb5e5e8ca01891734ae4b71ac73884290a57f",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
