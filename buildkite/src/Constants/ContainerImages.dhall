-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:77ef90e474ebfc6947e8942030326f58ad2b765e0f3a52b6c401dc608539747b",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:1336d422322bda780a1406a68af336575de98ae1c2757cd34690fd9c2231f275",
  minaToolchainBookworm = "gcr.io/o1labs-192920/mina-toolchain@sha256:1336d422322bda780a1406a68af336575de98ae1c2757cd34690fd9c2231f275",
  minaToolchain         = "gcr.io/o1labs-192920/mina-toolchain@sha256:1336d422322bda780a1406a68af336575de98ae1c2757cd34690fd9c2231f275",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu2004 = "ubuntu:20.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
