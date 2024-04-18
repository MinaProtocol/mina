-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:9c9757ecb33f81903469841dfe68cacda7c9d99d841ac42ec29e72ff339d0e8b",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:90447ce5cfa09b2f59744f9a16d236119ae0d527178ed82e330ea03077393329",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:90447ce5cfa09b2f59744f9a16d236119ae0d527178ed82e330ea03077393329",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:90447ce5cfa09b2f59744f9a16d236119ae0d527178ed82e330ea03077393329",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
