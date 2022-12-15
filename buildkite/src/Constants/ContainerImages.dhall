-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:d3e6a2d0dbccedc37af275732d832ead7175ec9972d3a9ff6372d77f17ab0f4a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:88fce50c10f38de314ee1ba2799042946dbdd3b0572b65dee6e59e7c3e9b8ec0",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:dd05269fb776ae39ef2a7d2dfceb150d29d8c0eb80637b329463c32f9dc04843",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:784a65da1a646d7a9c30c78b6301fb6df745c131126bb8cb7b34878391b8dcdd",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
