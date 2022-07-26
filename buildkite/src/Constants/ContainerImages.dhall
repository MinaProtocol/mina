-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:a7278eccb19fdf3870cfe130d229a677b9fc422c81c2272743e1cd9b5c352d4d",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:7b62e29683d4b3c5d503cb58a43014cc9e20681a5c87284b727bd55985300862",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:fbb198f1f400fab38fe83686b696771f359a073c38f6d9e34445206f8082cf81",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:3ec7d25df4f470c4fba717a8055ff6e94855afd37e1393274184a89d41796a3e",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
