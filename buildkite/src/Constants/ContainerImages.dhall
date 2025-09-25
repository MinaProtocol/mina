-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:6222f446894dca1dfd1e4fb5cc8f764801f63c2e3766d596b507a34d2e81667d"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:4d2bdd79af2b4ddd439fbf026c5a6cc3e494363d4b1182f74943ea3a334069ae"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:8afa734d000381e3f264302178813071655c9cb9ba814ab36d79aeeb850dec20"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:4b9d37a5646a728af3133ff844454976fe93c4dfff8bbbf8af9690200f08b128"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:ce9590903f5b37f74ad60d1d3a83cd7f89a0aa9e84013fb63d3603a8e32de380"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:cecf4c03fa21a1633ed4dc6b37f41b9f571771cc62be1aafd24b39e6a78d353d"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:8afa734d000381e3f264302178813071655c9cb9ba814ab36d79aeeb850dec20"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
