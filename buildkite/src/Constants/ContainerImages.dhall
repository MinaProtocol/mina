-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:78eb5d77229f6fc64f6d99b71c87b47a670d258351a947a8bd36069c61e62d7b",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:f1691606a84531bd43797caad7fb2ef6f910ea905693c6052f69cccc325ee554",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:f1691606a84531bd43797caad7fb2ef6f910ea905693c6052f69cccc325ee554",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:f1691606a84531bd43797caad7fb2ef6f910ea905693c6052f69cccc325ee554",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
