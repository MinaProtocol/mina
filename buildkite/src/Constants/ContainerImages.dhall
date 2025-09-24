-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:77a7cf784c684afa40fdf3e990776664974a8e5b9d65bcaab386f6456aa2ffc7"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:4e35ce4a5a9ae502c78e4a09211b380eb4c7f88065ae25ada9db8dad52257671"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a538e44ddf59ed5d10b38e56acd110b5022d27acc899285fb5d8e45efb4e7c85"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:b47f9b624544e799ef3c0adb085dc8cba14df50053179e7e1cbdb3bd27678f8c"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:e18f802b73f97b6191294775e52c064869383b8a92af0f179ff0398891f32ae4"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:42c0e4f8be6b6e890b106cb959715fbc92bac4a7695cdd61288ac8b7e63ab8f6"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a538e44ddf59ed5d10b38e56acd110b5022d27acc899285fb5d8e45efb4e7c85"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
