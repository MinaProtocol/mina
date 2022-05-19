-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:dd8d8746d2e2f95a84d89d4d20ab2435fbad00ebd9a2291e48f2bbc61fbb6cb6",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d25119fa7413d0ff252e92fa149592ac8850520115ae2e5e45af72e84ba329e8",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:6b267568b45723c6595844639596c5ad7d5998d8dacb9506f59c2e2081e80659",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:b571e9b95b954c1befadb61b4450583a33c5847f403f9e261a52a8286407886e",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
