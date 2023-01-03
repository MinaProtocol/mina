-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:f84ded6c73fe558b1637cd26cbbfe3d58030698532f0a3a3feae9e50e2fbac66",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:2bd7b9f44d0d908260d8a3b6d91564a864a6c532f643073df65623ce0c52c724",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:885b71746920298210e0514019d1f7ae8af173b52387aeaff5575f3945e2ccce",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:885b71746920298210e0514019d1f7ae8af173b52387aeaff5575f3945e2ccce",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:885b71746920298210e0514019d1f7ae8af173b52387aeaff5575f3945e2ccce",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
