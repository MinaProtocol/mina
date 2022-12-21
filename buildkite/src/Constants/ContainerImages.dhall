-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:0e6b39ddf36f0812b38b22fb2544f8c795f31a80c39fc3d03fbfbe048cac1b87",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:23114ce2005fb94a42331881a0207645e36fb6dce0c6a131bb6a78e783ff4638",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:e1e378b9c75d5a2778d9f39cb62835b3ff74a3e4ce964708f4ffb89f8b703a94",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:e1e378b9c75d5a2778d9f39cb62835b3ff74a3e4ce964708f4ffb89f8b703a94",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:e1e378b9c75d5a2778d9f39cb62835b3ff74a3e4ce964708f4ffb89f8b703a94",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
