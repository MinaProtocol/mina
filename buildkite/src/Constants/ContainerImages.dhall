-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:40947d6c7d8fbc4844695da181d178ce12155c745b358020f8cd77a59b530751",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:5894b8489a155cf230ea2b4f25c8c122a9c9e197c292477d7911c4944e6f5df5",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:0143ab966399bac25056f82253cd994017b444f989eb4814bb6f0d81b61629e1",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:b1274e37efaeebbebb4cb5e21e0aa7082b9ef1ae473dadb4b5d8bb95e2f06a1c",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
