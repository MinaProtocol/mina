-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:4b4307de7ca1c575003448793323ab33207b5e56c0d1c7e14ff6d66a0028b4d0"
, minaToolchainBullseye =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:c99accc1ef635c46d010d9f7151df7cdd7e2fc680a7d60fb9e526445de7af116"
, minaToolchainNoble =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:da0cf7eb0dc9e2decd5c4d76dea6c4723a1ead2fc8d0750d04368d74b1de4a6c"
, minaToolchainJammy =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:969baf296735abc81958c0a2192973562287f5c9f170442b44076047bde7a1e1"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:c99accc1ef635c46d010d9f7151df7cdd7e2fc680a7d60fb9e526445de7af116"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
