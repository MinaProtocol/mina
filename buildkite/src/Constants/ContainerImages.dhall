-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:a978b526278cf8aa2e8f82b4c884e609f83deb8adfd9c5bd64b7b4170d5ce767",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:8f6f5ab66b81ed1a9b565702a88be87e851a543c38ce9633dab94c8682b5da11",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:c023e75a2e4f8fb8a93a929a0cd12a574fdfcc6346d4b851d33d2dfa79e3143c",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:a0f41b5c111de33cee29086823c6351a7372235be9ecb7a40eb189e991b198de",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
