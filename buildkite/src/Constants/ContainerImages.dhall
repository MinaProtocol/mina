-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:33275bbe44bb8e5b2678d1482705f964df3b37e2540a43ef9a1d92433b795f83"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:3b17e388d8974fdbe4bbd5f77315519763c78148a4c91434d9add62de87ab792"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:4a2483e94a4bcf03b82e511a4f1ef926659b3c6c42e31e03c0b9765a12225ac1"
, minaToolchainJammy =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:4a2483e94a4bcf03b82e511a4f1ef926659b3c6c42e31e03c0b9765a12225ac1"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:3b17e388d8974fdbe4bbd5f77315519763c78148a4c91434d9add62de87ab792"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
