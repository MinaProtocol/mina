-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c12bac51feb11c9c3dcc795c0794cce66b6597b96b89115227196e953552ea40",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:4412a445e5e7ca1fe03dcf20c491b39bac01927f06bb1dc61063d82e085b9a2c",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:0535f414a5cb2e59e61a6fb04f573e884ecbde946111faf6815f3aceca550bbf",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:def612c5c0de43379a75b855f03ba65194de7886b7ee25bffd984eca74d3ac63",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
