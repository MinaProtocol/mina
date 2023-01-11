-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:4ab7574f83f5a75548d500ea38198f5377bdcb1a204fa12ca5c2e9f2017330c7",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:ce476217e79d6c43da2513a886c9fdf346c287ecefb27c726c04cae828f6de79",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:be93201add6f683d920f2d26b9c74dfee7539f4df085ec116e6749f140db3f94",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:be93201add6f683d920f2d26b9c74dfee7539f4df085ec116e6749f140db3f94",
  minaToolchain = "gcr.io/o1labs-192920/mina-toolchain@sha256:be93201add6f683d920f2d26b9c74dfee7539f4df085ec116e6749f140db3f94",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
