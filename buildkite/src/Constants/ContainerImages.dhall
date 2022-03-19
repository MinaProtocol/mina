-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:8a67b7e0ce956f961c656eae15588db0b4a3841cab9fd0b81c5a513b8604cf5a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:db7af91a3c979eb8a9c3bd852ce5ab52b73a9cc24d74b453c2d01605ce5a35f9",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:bfa9a77e31d06f14ef4ecbb9131ab50ac5c6c5b95b9a52d0e4b70071d876b613",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:0c2e2e7e7906a3a801c0126671305c0dad3391db37e48bcfb6e9e2567472301b",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04"
}
