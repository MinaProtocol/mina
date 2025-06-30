-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:ea894449da218191f03b311c356c7331a16df17f2e41809c4b2a7ee813c3cb25"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:ea894449da218191f03b311c356c7331a16df17f2e41809c4b2a7ee813c3cb25"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:ea894449da218191f03b311c356c7331a16df17f2e41809c4b2a7ee813c3cb25"
, elixirToolchain = "elixir:1.10-alpine"
, nodeToolchain = "node:14.13.1-stretch-slim"
, ubuntu2004 = "ubuntu:20.04"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
