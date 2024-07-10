-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBuster =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:d27c15e3143a99b86155ba57696020c00e2a296b388499b3e6fb364478ddda3a"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:966863de43c72c294e14762ae567404005f99654c54338a9a89b999476a36d1f"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:966863de43c72c294e14762ae567404005f99654c54338a9a89b999476a36d1f"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:966863de43c72c294e14762ae567404005f99654c54338a9a89b999476a36d1f"
, delegationBackendToolchain =
    "gcr.io/o1labs-192920/delegation-backend-production@sha256:12ffd0a9016819c720687f440c7a46b8815f8d3ad06d306d342ee5f8dd4375f5"
, elixirToolchain = "elixir:1.10-alpine"
, nodeToolchain = "node:14.13.1-stretch-slim"
, ubuntu2004 = "ubuntu:20.04"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
