-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:15df000872420f0bbb87dfba5a342d3a3dda57e3e5988f62686d38a5c2d1548d"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:58dde6b7a20a2c593d94a273f4363cfc9ab7fc4d814b7c71da1c80b82136e1b1"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:7dcd8d262e1577bf1dd911ae6501eb986780efcde5b9755e6a0577336128a5d0"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:def009325323ad496f8754cfc16a70e5cd5abaf09a1902b184118c137a32f9bf"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:812c7b7c00a1281c7a50e33fa12bca0a4c75b299e9959dab737668a3eba5ca38"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:a5962f492807f1074b09758c9b3cfa406b9173f2de1864e9fe2a9f45356c5573"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:7dcd8d262e1577bf1dd911ae6501eb986780efcde5b9755e6a0577336128a5d0"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
