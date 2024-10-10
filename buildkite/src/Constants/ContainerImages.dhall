-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:788ff4f57c022d4423bfab5084f2a6835dfe5e48291d3cce0c90bb6174629b57"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a1f60d69f3657060d6e7289dc770fd7c36fc5a067853019c2f3f6247cb4b6673"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:788ff4f57c022d4423bfab5084f2a6835dfe5e48291d3cce0c90bb6174629b57"
, elixirToolchain = "elixir:1.10-alpine"
, nodeToolchain = "node:14.13.1-stretch-slim"
, ubuntu2004 = "ubuntu:20.04"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
