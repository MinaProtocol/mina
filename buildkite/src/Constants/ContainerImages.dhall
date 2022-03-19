-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:3d10ce58338198cd94d1f78f89930f5c98363e1eb222715bc90570fbccdd52cc",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:2501decd86c3940c54695e09e07da683160728ea0f5619634017dccd5ba6068a",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:339ab77b9d0e630a8dd9fefe4136de3064c51a53e97c15a3bd47152b6b5550c2",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:2df81cf7bd733366a4d8f9ac48cdbe01f4eefaa4ac10a21094db95328deaf647",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
