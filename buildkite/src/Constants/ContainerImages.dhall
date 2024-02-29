-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:ddf13f719fd67ac5329401710675c09b049f2880140afb70ff65009534304d08",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:7e5b2f8de31c0369b76bad6ca96b6dab8d561a6b163277edf85893c9b8dc47e5",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:7e5b2f8de31c0369b76bad6ca96b6dab8d561a6b163277edf85893c9b8dc47e5",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:7e5b2f8de31c0369b76bad6ca96b6dab8d561a6b163277edf85893c9b8dc47e5",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "nixos/nix"
}
