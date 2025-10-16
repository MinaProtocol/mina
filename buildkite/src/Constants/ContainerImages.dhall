-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:0eeee54110b9813bdf1304e6d9ecbfa00354f52185b3a8143acf6cf000a5c481"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:0e8514b75a32e564678c1d4ff721c1446201007b54a861db8db1c39050c05821"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:d8f4d2e01d292ecc646fa2aeaa01d71fe396433208cff6b4b89455230d5d0b6d"
, minaToolchainNoble =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:5f00353e01e84be267c4cb8f81c41d5234783112fb70394c9debbc029a3e68b4"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:5836c1605c5b4f115a6a7236ab51f780a3dd2039dc81c7620dd2b9ee5dedb95e"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:ad1f2fbcfa641fd431049bd9bc52362dcd2d060149c6f40c5a3629fd0d4ae6f2"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:d8f4d2e01d292ecc646fa2aeaa01d71fe396433208cff6b4b89455230d5d0b6d"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
