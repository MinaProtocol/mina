-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:9f760d0773e600f205314bc9d098f4ddfce2756f055581d645b3ed49ef25c53b",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:1d77122f3d173f010de4a251c4060cd191e3f070135745d4cd76fe967ccf4163",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:dcbf93d58f0f5a22035dfc1b8d1e66ea37dcb4ae22f6b522a69f117e34295f73",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:4b8d6db83907e1082a24583acc843bd2c88584f0741433fdaa5113ee5e7b2e7d",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
