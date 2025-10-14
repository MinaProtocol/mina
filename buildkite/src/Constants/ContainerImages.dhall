-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:dfa8a0eb32742900d890590875a7f7436545cd46d8c4ff147fc6a29997e5d4f3"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:8e92e0b4c9202e0e5f31afd48713d28bde903959ff7e55cbc1c080b0a8df5e3d"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:bcc6b9899d5d99c83287c2735fb686a6169268d48b11262d9dfa03c1dfd0cece"
, minaToolchainNoble =
    { amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:0c6f1c0921c7f76be7b86948e1f9e82d8270002fc19f0b48647bb1604489268f"
    , arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:182f0aa05988c5a00cc1ca5a5b651904282f3a0f7cd75faabe0a52e7d332cecb"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a3e5c7dc30c67d8a9769deee282f0b5b2a513629bf272aa9b9ec7d6aee68a4e4"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:bcc6b9899d5d99c83287c2735fb686a6169268d48b11262d9dfa03c1dfd0cece"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
