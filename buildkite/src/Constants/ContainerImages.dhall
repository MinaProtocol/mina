-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:f9f1ce378fed059fc2b12819e42aeb0eef56e5ab4845242d5cc015bdf873d3e1",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:442076888284f0622be2edf27ca9249a87f76fc69bac5e619091d9a8606e517d",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:442076888284f0622be2edf27ca9249a87f76fc69bac5e619091d9a8606e517d",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:442076888284f0622be2edf27ca9249a87f76fc69bac5e619091d9a8606e517d",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "nixos/nix"
}
