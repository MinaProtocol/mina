-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:2578d7b35ef404d6da31179e2d6012e1e451d6254b214c0ecddeb9d281c66195"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:7473e25c4ab2da533cda28aa31990ed040b9a391e061eb266b4809682fec96a3"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:eefb87b7a0510285fe9d6224bb25968fc451cc03e653129bd11b5a97ea7d8d61"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:09f907d15e279e646b9c4cc0182d458befb605a7832d82be40aa3f0e92b9b842"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:18ae9bef88d9ac769aa48de7ab80909131cf8d307d7eb1bc61d47be15ae534f2"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:37d201999d9a4b0f6a112089dde673cd58ddb69ba8b96072f36be6ea5a9008d1"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:eefb87b7a0510285fe9d6224bb25968fc451cc03e653129bd11b5a97ea7d8d61"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
