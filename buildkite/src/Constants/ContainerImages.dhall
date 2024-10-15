-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:1e4b429fdf6a06e88abe9b4c9d54a80a3e818011a94806d070433a95d6af1229"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:1e4b429fdf6a06e88abe9b4c9d54a80a3e818011a94806d070433a95d6af1229"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:1e4b429fdf6a06e88abe9b4c9d54a80a3e818011a94806d070433a95d6af1229"
, elixirToolchain = "elixir:1.10-alpine"
, nodeToolchain = "node:14.13.1-stretch-slim"
, ubuntu2004 = "ubuntu:20.04"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
