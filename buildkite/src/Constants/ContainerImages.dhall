-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:71173ebccf6af3e24d27262a5071f3dd0bd2c40b9de1c258422fdb9419507d3c",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:9c4062e76fcd910ad60d3f1f58e2395f6a5e70f16fbef422442aedb70112ac73",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:9c4062e76fcd910ad60d3f1f58e2395f6a5e70f16fbef422442aedb70112ac73",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:9c4062e76fcd910ad60d3f1f58e2395f6a5e70f16fbef422442aedb70112ac73",
  delegationBackendToolchain = "gcr.io/mina-mainnet-303900/delegation-backend:1.1.1",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
