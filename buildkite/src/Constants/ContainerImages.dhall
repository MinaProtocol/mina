-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:c007e0cc1dec301a10df261f70f4843134d8580f26c6338caf77577cb0ced8ba",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:e03361bd306248af5ca998528a4accaa34aaa4f70492754dccee6474caf7144c",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:5311621c166b64ea9bd28cb6d84a83c785d5766370abd91ae6c9c90f44fbcf37",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:463c3350724c1b2ee1d17ca41aa2e1f25e2a6a6691dce796c132f30ecbf21f33",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
