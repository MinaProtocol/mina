-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:28cdd5f9de9bec931bfcd220333b491d25f48a02414d47f4d45e5369a9e8a7ab"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:4636c12c35aac7ecf32f1900fe56074d3e8bec9570ef62f77e3824004ab01138"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:85cc92ee374568d19b5daac38077ab85318e969ab8c1d6c60143451dbce2d7ce"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:0c7a103bd024e054ba21171aed8ef4b99e4b1603b50be1ce33ba073882dd63b4"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:24bd93165d0fbfec6dd23b67d69ed62f8669c9e9d3ec70d6395deb8be566e996"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:2a6088bfc2ed0d6b2735091a9f974b418f857151266e4dcd13eb018a76d11fd8"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:85cc92ee374568d19b5daac38077ab85318e969ab8c1d6c60143451dbce2d7ce"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
