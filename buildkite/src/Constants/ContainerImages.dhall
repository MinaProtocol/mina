-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:622986bca0fa857a3e7b5d70345cefcef8b2c9832af3749006571c2dc3bcac62",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:41ddf17fc9aedfc96c73e2755b66d3ad24fe892603cf635ed499d3cb050b2de7",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:ff82677b01a8219ed1958874a6d9d940e942d1d3117e9899cacbd5463254749f",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:6fa0639408c46766bbd13566de3753d6b7558e99ed26f3a2fe5f3ff113c5f3e8",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
