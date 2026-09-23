-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBookworm
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
-- NOTE: postgres is the server every archive job runs against, via RunWithPostgres
-- NOTE: postgres 17 matches the version the published archive dumps are produced by,
--       so a production dump restores into CI, and it carries
--       pg_backend_memory_contexts (PostgreSQL 14+) which the memory benchmarks read
-- NOTE: postgres comes from Docker Hub because euro-docker-repo has no 14+ tag;
--       mirror one and repoint the constant if Docker Hub pull limits start to bite
{ toolchainBase =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/ci-toolchain-base:v4"
, minaToolchainBookworm =
    { amd64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bookworm-devnet"
    , arm64 =
        "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bookworm-devnet-arm64"
    }
, minaToolchainBullseye.amd64 =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bullseye-devnet"
, minaToolchainNoble.amd64 =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-noble-devnet"
, minaToolchainJammy.amd64 =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-jammy-devnet"
, minaToolchain =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/mina-toolchain:f009c00-bookworm-devnet"
, postgres = "docker.io/postgres:17-alpine"
, xrefcheck =
    "europe-west3-docker.pkg.dev/o1labs-192920/euro-docker-repo/dkhamsing/awesome_bot:latest"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
