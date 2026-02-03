-- TODO: Automatically push, tag, and update images #4862
-- NOTE: minaToolchain is the default image for various jobs, set to minaToolchainBullseye
-- NOTE: minaToolchainBullseye is also used for building Ubuntu Focal packages in CI
-- NOTE: minaToolchainBookworm is also used for building Ubuntu Jammy packages in CI
{ toolchainBase = "codaprotocol/ci-toolchain-base:v3"
, minaToolchainBookworm =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:5251a76936d040fd645cd60b737b74439668fbf23e685f4e4fa91ebaddd9fe24"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:b2d3f8c64778db0af2a1e94a83665ffa1e7d7777ed053e44c5a71dad90179418"
    }
, minaToolchainBullseye.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:251cae198a35106320a498344edb585efa27e4ef19fb62a16f5703e42e0b8632"
, minaToolchainNoble =
    { arm64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:0f91ca09ebcb2e240574a765189afa076a69651734a6dddef26b42eb5c23594b"
    , amd64 =
        "gcr.io/o1labs-192920/mina-toolchain@sha256:4e86907edec23da0e8f29cceb73c3fdb830fc224964526869c713936c97cf7e4"
    }
, minaToolchainJammy.amd64 =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:22a7f4c7882dae53908251ace50bf3ad1cec553600a1c2688f1788fc029861e5"
, minaToolchain =
    "gcr.io/o1labs-192920/mina-toolchain@sha256:251cae198a35106320a498344edb585efa27e4ef19fb62a16f5703e42e0b8632"
, postgres = "postgres:12.4-alpine"
, xrefcheck =
    "dkhamsing/awesome_bot@sha256:a8adaeb3b3bd5745304743e4d8a6d512127646e420544a6d22d9f58a07f35884"
, nixos = "gcr.io/o1labs-192920/nix-unstable:1.0.0"
}
