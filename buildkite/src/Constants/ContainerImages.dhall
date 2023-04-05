-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d3b60370068f39905b96485598523586341a594425132cd3a7bb7f1f39a451fd",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:d2d9793d7fc659df8ced68f3d122342d6b62d90dced1ab044e5cc9ca2defed96",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:d2d9793d7fc659df8ced68f3d122342d6b62d90dced1ab044e5cc9ca2defed96",
  minaToolchain         = "gcr.io/o1labs-192920/mina-toolchain@sha256:d2d9793d7fc659df8ced68f3d122342d6b62d90dced1ab044e5cc9ca2defed96",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
