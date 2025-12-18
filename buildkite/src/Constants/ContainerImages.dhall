-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:d3a479556ebd293ffdd1fe2cd552fe1a03ceaf118c9fcbd29d3ecb5cfad62326"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:4d0f55b32c072d59a4a09c5b4484c6afb6600da90e55aed645a59c841cb6ee36"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:20e86f1931599826c888a88ac956de0cdbad326bf155b6cf8e1536c3509b7a17"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:6fa48067fea8d81e15379781ad22ba99ffec0623a2613ea5b1447b32dbdd3114"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:d81adae569e02eb5295f7cd56aa53df95576d8ad001358066bcae3a612cc39b7"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:42d55ac7521096ade25c9b0d24062894fa433bf214c07cc4f991df2d2d5392f3"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:20e86f1931599826c888a88ac956de0cdbad326bf155b6cf8e1536c3509b7a17"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
