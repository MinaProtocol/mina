-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:12a68c1a8024fa5a87f28eedaabf7f5aaa1843d89af2987360796f3c91bb2479"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:8479f26d8cd58f8e663b8e576ba84242217c2b2e272fcd4cd50a13f04f4ac9fa"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:c9ae80ed80d78080d8d3c5c962dc4480edfcffca2f08eb159fc4caec4959198a"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:4c713087da8cd2159c67ced71d0f1b546a85dabedf48ece6190c5d521fdcebbf"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:1dacf0645b6c6d60abe08cbe1a3a3ef5348fd56bee718bf35cf75f151c7319bf"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:cadfb4d932aa88588ce610e14cb374959251cb3639ba5c48777f82260f79d49a"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:c9ae80ed80d78080d8d3c5c962dc4480edfcffca2f08eb159fc4caec4959198a"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
