-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:d58f431177b453f3dddd48119d1ca86c9daf9c51f54f2daec5092bb5de674dc8",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:d2305beb4ed343113b79a6cbf88d25fbd4fb9b85913a2fe039b6a545cec63213",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:ab84f1d19d73ca67d31ee7e11eafd0b5a6bea3fb165b2f3f0469fb6af3efc9e3",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:68bd612b2615946740a4e06dd0e9c3a87fd074cea1456efc1a0bc6149409c923",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
