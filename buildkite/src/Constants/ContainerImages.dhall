-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:c8469d75e0b2858b25195c44d91ca6e204bae959936bb7bc11c9fab57dfdde7e",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d4d9bf49c48913d52c18f8aee30c62e7d54b06885c960e552e3431ffd8cdff4d",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:02ecad3476bbf1e1f3c29aa3f26acfef58035ab7320df8007d5f413c5dcba002",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:6d02eb5f3fb419f55b76fd44dfbde72988fd88fd8946cf4dcaba4f3c12a6f49f",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  rustToolchain = "codaprotocol/coda:toolchain-rust-e855336d087a679f76f2dd2bbdc3fdfea9303be3",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
