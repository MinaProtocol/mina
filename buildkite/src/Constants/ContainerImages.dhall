-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:e4920236094ab23caad9ec9cda39babde6b777541db054e8138f71ac464f57b5",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:152fd2d4375fa3ecbfeb60608f62bd4430f19582092e69809bc445c7a1f2f5f6",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:d9561c6dfe0e77106233f6e000fa249f41abc26ced742cd641717e4d133afcc9",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:d9561c6dfe0e77106233f6e000fa249f41abc26ced742cd641717e4d133afcc9",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:d9561c6dfe0e77106233f6e000fa249f41abc26ced742cd641717e4d133afcc9",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
