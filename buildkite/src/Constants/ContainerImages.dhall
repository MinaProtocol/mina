-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:198179cee3a569b0a5f823ff8a8b91144ff6deba010155fb5916a12b17968d4b",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:147d57a1cb0162a0914a7da5a31f4afcc98a13838ac4625afbbc08dda7c0720f",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:d32257baf85975749ff791c5d2e2d5b25a06a126c7c897243f2940f983f8d57e",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:288062008e18e0f7608d608d7fb57d53204b6f6c1dbf534d48b8e34b3b82d228",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
