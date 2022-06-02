-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c56fac6589e872964eb9a7c93880f3a6ca82b3c3a00ff7435339412ddc4f56d9",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:e3a636f15c1c740973b4306ef5e7fd32871155659f7e8ebb6df3837797b502b9",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:4b83ecb73dd2002a9466be33d473e08add9fc02697dd7ff4b3b77921a31349b9",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:a79e49dd051dfa1e26728138629ab0879dbf3a0fc75c0f614eac7dff971b40db",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
