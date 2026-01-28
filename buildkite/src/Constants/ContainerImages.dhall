-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:ff2bfbd0dc07736c5681b4a946322b9413f6382d7208873a9c9e50db72709ed3"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:e96b796483469ea4b56a30341c1ad82b75ba009d5888bed0d086741553b0535f"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:aa79d803512e2c7d7f3944a4658eec2280383df4db64be921393d93abf3782fc"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:fe3975dff118f933ff0537a908c5f96be04583019f935eb690d4e5720cda8b25"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:ccafd5ee7a4ec75b52c5662a6f7925b6af41905713227cc13883a4f21113231e"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:6dad19881fab078431ad0ad3d5caf45447b8651dcd5060c9e0e69e68c2df8d86"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:aa79d803512e2c7d7f3944a4658eec2280383df4db64be921393d93abf3782fc"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
