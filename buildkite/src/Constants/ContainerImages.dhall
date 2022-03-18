-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:0ef97bd4cc4fded97b67b0e4a0b3960d19d846094efc5bd5095076d6ad48b45d",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:a78517f88fcb49f619708fda5ab5e30ac0bb0d80423813b3b77c1da1c8d2765c",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:b4bf0b092021ce4dba8b91214cf62e4f4d808752c69e2e4a8e8f3054dfc0d1c9",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:60122776fc34f7a6047deb030ac98f87a50c5e13c11f75b8a2003f86e0c9ca1f",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
