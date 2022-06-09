-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:5b8cbb0ddf046770f1f3a7917b5800dfc72fded64f243ff6926cce2e908e6404",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:bdedc2ec6656b05f3b43eb90f25b61740a147209da02003cb5bb145540d51a51",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:caec07eb37307fa64efedfc10e2482b93261f87e54cf608902dc6a395b8b45b5",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:aea39d2f4bab806a4632966f405ea539415f48017ff86194537c2f93cb517155",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
