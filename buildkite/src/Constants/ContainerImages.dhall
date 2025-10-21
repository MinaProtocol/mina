-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:a3517722b1573ac19f9361d42aa0b5f15a108d62fa73f97f0a74e195af1a2e90"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:b4a7040b64473f89e51372ab6e11f9332730e085766aa157c25e28c6b9c0c6d4"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:524a3fb77d6702f38ad63ec737e398478e082387753b8d01e1ccf607d2917343"
, minaToolchainNoble =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:51c06affdbee4cdf3189fa716e277a8242d44aa9f91798155cd7fddc26bdc958"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:adfff17bf21b79efc3b2d54d0648049a36fa7b54b732773bd7f2f651869c1f54"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:6db30a6faf94f7dcc23a14bcbc01d558b2164955067fd21eb92a981fe231dfe1"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:524a3fb77d6702f38ad63ec737e398478e082387753b8d01e1ccf607d2917343"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
