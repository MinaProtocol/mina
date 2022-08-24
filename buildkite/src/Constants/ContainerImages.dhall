-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:106a6c5a5a8a4df8b26464edf9b0bd1cec35124ecf7d8340af4561a54812c701",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:1fe11f2e4f6d7483411d0966509cb5d0b108d903e7dccee94b97a710be78ff40",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:56e8058904ada5081e0839468c7ac7c7d2438a49a452e9f263b271bc87946db5",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:421b0dcf6adbd2622264b45b1a5deadcc0ace69841fd484492cdd7e3bec330bd",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
