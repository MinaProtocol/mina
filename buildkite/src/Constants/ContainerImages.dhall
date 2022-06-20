-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:4d22b936979bb8e71e570b84e39377da426b7b1e4b23f8367ac45ae92d2a758c",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:080827729c83b981a7298a3a71b383e00b6efce4153999bdf8fc67d4e04f6626",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:2d60de7e971d712da2f4315e52cea3660737c05b7e76eafc6c167e7083877de5",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:94167d5f17b76353dc12ec425a1929160e069da1d063c2e3fae661994494c22d",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
