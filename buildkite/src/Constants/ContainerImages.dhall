-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase               = "codaprotocol/ci-toolchain-base:v3",
  minaRosetta                 = "gcr.io/o1labs-192920/mina-rosetta:\\\${MINA_DOCKER_TAG}",
  minaArchive                 = "gcr.io/o1labs-192920/mina-archive:\\\${MINA_DOCKER_TAG}",
  minaDaemonDevnet            = "gcr.io/o1labs-192920/mina-daemon:\\\${MINA_DOCKER_TAG}-devnet",
  minaDaemonMainnet           = "gcr.io/o1labs-192920/mina-daemon:\\\${MINA_DOCKER_TAG}-mainnet",
  minaDaemonBerkeley          = "gcr.io/o1labs-192920/mina-daemon:\\\${MINA_DOCKER_TAG}-berkeley",
  minaTestExecutive           = "gcr.io/o1labs-192920/mina-test-executive:\\\${MINA_DOCKER_TAG}",
  minaBuilder                 = "gcr.io/o1labs-192920/mina-builder:\\\${MINA_DEB_CODENAME}-\\\${BUILDKITE_COMMIT}",
  minaOpamDeps                = "gcr.io/o1labs-192920/mina-opam-deps:\\\${MINA_DEB_CODENAME}-20aa18425de3e013e965d6f40c923d9379801dfa",
  minaToolchainStretch        = "gcr.io/o1labs-192920/mina-toolchain:stretch-20aa18425de3e013e965d6f40c923d9379801dfa",
  minaToolchainBuster         = "gcr.io/o1labs-192920/mina-toolchain:buster-20aa18425de3e013e965d6f40c923d9379801dfa",
  minaToolchainBullseye       = "gcr.io/o1labs-192920/mina-toolchain:bullseye-20aa18425de3e013e965d6f40c923d9379801dfa",
  minaToolchainBookworm       = "gcr.io/o1labs-192920/mina-toolchain:bookworm-20aa18425de3e013e965d6f40c923d9379801dfa",
  minaToolchain               = "gcr.io/o1labs-192920/mina-toolchain:bullseye-20aa18425de3e013e965d6f40c923d9379801dfa",
  delegationBackendToolchain  = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain             = "elixir:1.10-alpine",
  nodeToolchain               = "node:14.13.1-stretch-slim",
  xrefcheck                   = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
