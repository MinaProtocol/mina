-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:9ab5180d68b0e8f418f118cf3b47062aae97349c786a4f518fc7c6eaea38fd1d",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:066a4da75d6e838cfe92df0df9d5566d64f81568e23b6b41a05af3ba93a3cdbc",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:c8bd19248e9b480897bb9128ffc3802980434cea196a5848bf10ce53b1f1d4f3",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:b3276ec51de106f399ba07bd09e5f3e352da7e5d8e337fc07840bebc1391c973",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
