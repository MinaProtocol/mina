-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:2578d7b35ef404d6da31179e2d6012e1e451d6254b214c0ecddeb9d281c66195"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:cb7253baa6389779bf6986285dfc34ed60ce389bebdeae3bb68c25945ba6670b"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:f26c26154d8185dc473d25bf19e71670beee8d8083c03acb3a242a56154d9511"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:09f907d15e279e646b9c4cc0182d458befb605a7832d82be40aa3f0e92b9b842"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:190f31de9aa9b6da0f2be93e467f0307fbc85fd0c32e2e742e8b566bb2e23a45"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:969baf296735abc81958c0a2192973562287f5c9f170442b44076047bde7a1e1"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:f26c26154d8185dc473d25bf19e71670beee8d8083c03acb3a242a56154d9511"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
