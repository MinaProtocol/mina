-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:8ca4a4c63ab252147a8943d148a1f496a1f3abdf617e4e25a9e42f772b931745",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:6415490ee80c5bf8f182425f4df6eb8332539f2731603db5075106c33bbf23f9",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:0a644baa77f257f0ae7690dd484e2f9350cc36426b1659090446a135edd77509",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:620cc469a13ceabc213ca452fa091f9e091c929044820ea4cb0548e36a29377b",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
