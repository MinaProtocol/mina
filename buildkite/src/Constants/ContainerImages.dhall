-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:36f1a221486c1ff6ac55fda7dfbcd81fe9992dbda211b25600ff693445d6c985",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:525ade511d01ce66822f11b35893bed69b55d3fc9a4b872914214ddf67cf7e30",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:05b7ab374f3d4b837a27e630dd8aad96d2ec776ec9c21e84924f50ef5a263a74",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:f0a96582499cd2a05ba8181b8767866bb928226f0cc369a16102c701def621c7",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
