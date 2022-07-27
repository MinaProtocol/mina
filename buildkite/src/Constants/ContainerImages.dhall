-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchainStretch is also used for building Ubuntu Bionic packages in CI
{
  toolchainBase = "codaprotocol/ci-toolchain-base:v3",
  minaToolchainStretch = "gcr.io/o1labs-192920/mina-toolchain@sha256:ffcc975506348d5f9ec465d1b15e43a2e5e4cb370f007ff4a76cfe52f6ff031a",
  minaToolchainBuster = "gcr.io/o1labs-192920/mina-toolchain@sha256:6362592627c831507beed837a4862b435b60db4007e54d12d4567040cc549a73",
  minaToolchainBullseye = "gcr.io/o1labs-192920/mina-toolchain@sha256:7aff0638273ff094cc4c488b53af69894c42edd783f4da3979ace0d593775178",
  minaToolchainFocal = "gcr.io/o1labs-192920/mina-toolchain@sha256:300068339bad9f6145a4ad9d92d141a9dc8bf43256c85fde8ab4b0c3b9c617b0",
  delegationBackendToolchain = "gcr.io/o1labs-192920/delegation-backend-production@sha256:8ca5880845514ef56a36bf766a0f9de96e6200d61b51f80d9f684a0ec9c031f4",
  elixirToolchain = "elixir:1.10-alpine",
  nodeToolchain = "node:14.13.1-stretch-slim",
  ubuntu1804 = "ubuntu:18.04",
  xrefcheck = "serokell/xrefcheck@sha256:8fbb35a909abc353364f1bd3148614a1160ef3c111c0c4ae84e58fdf16019eeb"
}
