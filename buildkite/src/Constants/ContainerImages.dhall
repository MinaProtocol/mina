-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:0f04785b20c7cfa7be5afd6d84eb2f485a17e650167e148c55670fc11c3906ea",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:dc829f1527833d505af11ec7f8fb9eca9d54c0616cd802540189ccba95fca302",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:dc829f1527833d505af11ec7f8fb9eca9d54c0616cd802540189ccba95fca302",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:dc829f1527833d505af11ec7f8fb9eca9d54c0616cd802540189ccba95fca302",
  minaCaqtiToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:9149394176f71fd44ebb414e370e26448111304e05256f6580a404ae6f41d372",
  minaCaqtiToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:a663308c0c00ddbc89a6b4614e7bc933a449fb712137bfd5a8eb074daa139f15",
  minaCaqtiToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:a663308c0c00ddbc89a6b4614e7bc933a449fb712137bfd5a8eb074daa139f15",
  minaCaqtiToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:a663308c0c00ddbc89a6b4614e7bc933a449fb712137bfd5a8eb074daa139f15",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
