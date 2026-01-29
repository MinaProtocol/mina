-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:5be914995c24bb82ead46a5354e5b7f141c7745e894e122b248fb4692fb1e517"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:9bcdf367cc30bdcf7caa35b64803c9d1bf338ff7f74a86df834a38ed45e1aadf"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:08b69941311c2dd68de0cf44be0a8d13eb75ac999f0f8dcd71e4e6ac38538f97"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:73d8cd51941db968c8f69e7573960de9dfc73071399f2884b7d759ad6d289e98"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:2bc949fb48e85099b8f63c9988981c16a003e57f6c7ae45210d345320df42d15"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:bc8ff344350bb6de2e52fb2b74345405ffc87821e238ed0c20c1a297d9991e6f"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:08b69941311c2dd68de0cf44be0a8d13eb75ac999f0f8dcd71e4e6ac38538f97"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
