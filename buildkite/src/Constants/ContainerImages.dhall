-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:6d9916e82098887c9ce14d99e30af920da80f6113a98916cbf4c8979924fa198",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:75975a4d24ac4ab7bc8a66fa3ed9aeb27dfefd53e2e69342c518b7a943a65ce8",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:90157674e23dd2c2d515e6e28ae442c1e5d551291cd598aada6e410237f9b575",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:f25857dbeb0eb87a89306f38fba590034054704ff0632250006148e65368e318",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
