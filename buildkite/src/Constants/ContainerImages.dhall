-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:3062c8363df424c4dad1f325b7bbceb82b299485e8e820d1ae21dd1b33d975ed",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:0a4d8ec1c1b5ad3988d70b1c012af5d97e66874a985478fee8e5aefd27359569",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:fbd3b1dbb11472e00c22e6babc511ca51fe00db62fb7736ef568b01fb7f49a31",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:13628b16a56628960260598f6021222e5ab6e9f3f5b64c13292a34f71a686d7d",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
