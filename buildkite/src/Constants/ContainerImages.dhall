-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:cfe9b793f5d67ecbc98cd8f943f89e15b7e402369d39a250a93399146383262e"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:cb775fd01376736f4942255b63f8e9745f3f23e15839836b0fe60c3e2dfe9e4b"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:4a2483e94a4bcf03b82e511a4f1ef926659b3c6c42e31e03c0b9765a12225ac1"
, minaToolchainJammy =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:4a2483e94a4bcf03b82e511a4f1ef926659b3c6c42e31e03c0b9765a12225ac1"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:cb775fd01376736f4942255b63f8e9745f3f23e15839836b0fe60c3e2dfe9e4b"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
