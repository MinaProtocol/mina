-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:c63dda05f4e546e5b49a992cd2a4ea223dbe6fcf2d2dcf902e46befc7f3538b1"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:0e25355e6ee9d56abee80ec37676445b132a1df85c4d14ff2ea85a35b29d8c7a"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:532b80e8811e7054ab89426ba8b476de6ada8ba0702e093473f1fcba7a1e4d24"
, minaToolchainNoble =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:f8c910c1d2dbb2cf76e992ef9f356293087e1e94f95371e06f579964d5eb8056"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:11176d7f30fe68496ab0d19a3cb1a0c44bad8f3acecdd74ceb84e6e4212acdc2"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:d51c024ee79a742b2821ef15436e285b0f5788f64764b10f5d27fa609e0d040f"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:532b80e8811e7054ab89426ba8b476de6ada8ba0702e093473f1fcba7a1e4d24"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
