-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:a164696114ea85776779ab012f4fba2c56a7edab990d48c0704f9363e809f8c7",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:95b93e65ffd81791e26d8aeceaf03ea4893b44179e611b4451ee976cf233204f",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:46fc2b08562c536a5a7719b9ee27ba6364f4f32b392f88613f0829900deab3be",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:46fc2b08562c536a5a7719b9ee27ba6364f4f32b392f88613f0829900deab3be",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:46fc2b08562c536a5a7719b9ee27ba6364f4f32b392f88613f0829900deab3be",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
