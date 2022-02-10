-- TODO: Automatically push, tag, and update images #4862
-- TODO: Make focal image distinct from Buster
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c4873c52041996a4eacdd96d0310b909a099689552c8b4fec7d464872abd1e1f",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:ea8323bfd51f0171770f77e63d3dd915d473aecbef8a1f173348ce339668fba9",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:ad94c2373f45a8a5af354ed12d5eb34ad64b1140c0811a9935212ea0a5d3c4b0",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
