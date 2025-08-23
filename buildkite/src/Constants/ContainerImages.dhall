-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:1d7b8142aba55277379693f8d1df3e637a864f1c6cec992a55fefb4c7fbe83fc"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:68372c2c836b2349502404d7e0fa7a3c5b67b9f22c42cfc4d428efac231ddc36"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:de1e294d013c8912948f098617adc4ce6e122cc8c46e1b754bdc0a774affeb7e"
, minaToolchainNoble.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:67c5ec448c0b956a833e954023cf759fdcd474f22dd6b73b0821246ab2c2b01f"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:de1e294d013c8912948f098617adc4ce6e122cc8c46e1b754bdc0a774affeb7e"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
