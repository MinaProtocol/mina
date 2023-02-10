-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:e46be13da3740913ec46b1927c6ce3ceabd23b3295252e9860bfe47027a76bb9",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:28b08326d18c17cb9c14e66a70cdfbbf657ad12233c475a84a0b713d4890578e",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:6bdb7248aa56f2c2e440597c8ae9e8018fa293d296398d091e2a1006bac4efb1",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:6bdb7248aa56f2c2e440597c8ae9e8018fa293d296398d091e2a1006bac4efb1",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:6bdb7248aa56f2c2e440597c8ae9e8018fa293d296398d091e2a1006bac4efb1",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
