-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:fea78b647b3f33673a37cdc081a3a673ffc203f415cb26d1e83a901a3581b907",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:66ca6298dfa9aaa1ca22e2611d37b30280e6e72c5fe6166612b8c2cabf58bbea",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:66ca6298dfa9aaa1ca22e2611d37b30280e6e72c5fe6166612b8c2cabf58bbea",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:66ca6298dfa9aaa1ca22e2611d37b30280e6e72c5fe6166612b8c2cabf58bbea",
  minaCaqtiToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:66c64db5374d464de636bc8aa63ea961039e74a17c838f4924b30dc3fd0ca992",
  minaCaqtiToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:c7bd74eee8e6729fd3111a51a07052cde50acb2271f32c44ac26091eaa86f9f2",
  minaCaqtiToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:c7bd74eee8e6729fd3111a51a07052cde50acb2271f32c44ac26091eaa86f9f2",
  minaCaqtiToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:c7bd74eee8e6729fd3111a51a07052cde50acb2271f32c44ac26091eaa86f9f2",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
