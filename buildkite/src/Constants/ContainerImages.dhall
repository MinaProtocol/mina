-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:fef252befc3721f3957e03995daeb11b7dd6bd833bf0f671df6d11cb9762ed5a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:eb28ecabc1ac1f8742ac323a55d92287f339a7187f8c5345916c0f6077929307",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:4facfa57553509d43c60e1f9908ba4bb5de7fb8988acb2b16208c8a16cf1c909",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:c65e66223ea19b55c8ce44e03a3344a7e12b6d4ec1dc1552234db278e541f629",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
