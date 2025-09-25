-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:0c2764790ae18788b97a9c6361d7c4b0a96c515d176226868d929415e24f8251"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:deb63964399029d681e39ac4ff529616b179c72fff3a0ab350e11a7099f6f23d"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:db00940ea2c778592a520da755388014231db52aa2d89e0c853abfafc4fa5846"
, minaToolchainNoble =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:669c4053d2f3b7ecf5787b9dc0d908b7061c8a8908dcc766c4de57bcd1c67fa1"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:2a71e234ca0cc42a663e42daabef3736207fd91bac414b2d511b30b336529b74"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:b16023b65bb90fc2242c83b7c9f3f3c62aca521f316a16a45f5f7cb115e95f15"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:db00940ea2c778592a520da755388014231db52aa2d89e0c853abfafc4fa5846"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
