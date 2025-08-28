-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:2578d7b35ef404d6da31179e2d6012e1e451d6254b214c0ecddeb9d281c66195"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:6d7141e6b367f95f55276278efe2f8d22b9f2f56ac6338b272dacff54fa94f91"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:15ee89ff49c80eb5826994e8248ed9ba362e8be357c7e621bc4258bb08a5e4ce"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:09f907d15e279e646b9c4cc0182d458befb605a7832d82be40aa3f0e92b9b842"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:67c5ec448c0b956a833e954023cf759fdcd474f22dd6b73b0821246ab2c2b01f"
    }
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:15ee89ff49c80eb5826994e8248ed9ba362e8be357c7e621bc4258bb08a5e4ce"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
