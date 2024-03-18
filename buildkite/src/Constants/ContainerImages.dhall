-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:5e46491494ba1630962fc160a96e28262a1ccd782780033f313478f7ed6e9d59",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:91c034a9dd2b1a9bbc8d8fc36c01555ea84463f391c36473810e6711574162cf",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:5e46491494ba1630962fc160a96e28262a1ccd782780033f313478f7ed6e9d59",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:5e46491494ba1630962fc160a96e28262a1ccd782780033f313478f7ed6e9d59",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:5e46491494ba1630962fc160a96e28262a1ccd782780033f313478f7ed6e9d59",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
