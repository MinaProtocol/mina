-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:a1b329214d7ac5b7e74a87aacd8c1c73c136a11d27e807f3759081f445c9d5f4",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:a410363ef32893d11c7b7d3316e7f76c8e45905ca9e14a547859c39a72c48472",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:d6a162257680a757cdbb39cee5762e3ce4e4d03b7f21fe60762b78b64766e098",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:d6a162257680a757cdbb39cee5762e3ce4e4d03b7f21fe60762b78b64766e098",
  minaCaqtiToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:900320a7063bf686d2e5a8fa67a111479b3274f3439beae88f96364e209b7a0d",
  minaCaqtiToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:609210748ee04b2926b86d6590e29b5a32d4709eefdf907f83b819f38cce8f46",
  minaCaqtiToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:609210748ee04b2926b86d6590e29b5a32d4709eefdf907f83b819f38cce8f46",
  minaCaqtiToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:609210748ee04b2926b86d6590e29b5a32d4709eefdf907f83b819f38cce8f46",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb",
  nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
