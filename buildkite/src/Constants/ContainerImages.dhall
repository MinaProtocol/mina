-- TODO: Automatically push, tag, and update images #4862
-- TODO: Make focal image distinct from Buster
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:cdd590b5b2fd98476642f869524d73006ff556c4f10ce62a99893a911467048f",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:87747889cf5ddbd1080a9453b993d503c21e08afee8b26758f3787027d6deb4d",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:dbe4907bb7a79437f60b25473abb3a1a28eb896e3353f2d909cd10cfbec42d7a",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
