-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d4d93631c0f14a03d89ce1e4d0e9807a9c27e3ea6398e40528dbe22c1ebe6503",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:22b849e7d1adb6ece55e6a000a946e573f5926adb9dfb0f87569bd897183f723",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:22b849e7d1adb6ece55e6a000a946e573f5926adb9dfb0f87569bd897183f723",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:22b849e7d1adb6ece55e6a000a946e573f5926adb9dfb0f87569bd897183f723",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
