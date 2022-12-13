-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@gcr.io/o1labs-192920/mina-toolchain@sha256:77108b9985e1e65ae3d3dc22c6fe2114530ba44e9a1d890642b9aefc7f44ef3c
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@gcr.io/o1labs-192920/mina-toolchain@sha256:b90422fb481d197187e09c34712f776f2fd2f81acf35041840a833c641c59fc5
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@gcr.io/o1labs-192920/mina-toolchain@sha256:fbf9d1264ae445ec85c2aff0ba181b352c308ddff8498ef46c1bd2ada446dd30
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@gcr.io/o1labs-192920/mina-toolchain@sha256:6621e0ec569c49fd00efc381f897c8a11c9aa6828cb448267c57ff36e7612c1a
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
