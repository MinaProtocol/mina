-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:057849464c9638be96478f55b81ffa175631a4d0bf82447c86f773c52908764f",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d9f131e2a7518f639d4fe012fe204b129dbc15e1223fa3d5bd8c507f986b51e8",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:5f98fcbba8121ac38a85058ac3787d935eb41da3facf8f0a3bba71a863b872e8",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:dcd24742ddd461304e04e392a602c723a44785a06e58496a820e953e895c20aa",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
