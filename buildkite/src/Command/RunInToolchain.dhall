-- Helpers for running a command inside the mina toolchain docker image.
--
-- Submodules: the Buildkite agents are configured to NOT auto-checkout git
-- submodules. Most CI jobs (lint, dhall checks, tests that run against prebuilt
-- artifacts) do not need them, so submodule init is OPT-IN: the default
-- `runInToolchain*` wrappers do NOT initialize submodules.
--
-- Jobs that build code from source (the proof-systems/snarky submodules are
-- linked into the OCaml build) must opt in. They either:
--   * use a `*WithSubmodules` wrapper (e.g. runInToolchainWithSubmodules), or
--   * set `submodules = True` on the `Config` passed to `runInToolchainImage`
--     (this is how Toolchain.select threads it for artifact builds).
-- When enabled, `git submodule sync/update --init --recursive` runs on the agent
-- host before the toolchain container starts (the host tree is bind-mounted in).

let Cmd = ../Lib/Cmds.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let Arch = ../Constants/Arch.dhall

let FixPermissions = ../Command/FixPermissions.dhall

let Config =
      { Type =
          { submodules : Bool
          , image : Text
          , arch : Arch.Type
          , environment : List Text
          , innerScript : Text
          }
      , default =
          { submodules = False
          , arch = Arch.Type.Amd64
          , environment = [] : List Text
          }
      }

let binfmtSetup
    : Arch.Type -> List Cmd.Type
    =     \(arch : Arch.Type)
      ->  merge
            { Amd64 = [] : List Cmd.Type
            , Arm64 =
              [ Cmd.run
                  "docker run --privileged --rm tonistiigi/binfmt --install arm64"
              ]
            }
            arch

let submodulesInit
    : Bool -> List Cmd.Type
    =     \(submodules : Bool)
      ->        if submodules

          then  [ Cmd.run
                    "git submodule sync --recursive && git submodule update --init --recursive"
                ]

          else  [] : List Cmd.Type

let runInToolchainImage
    : Config.Type -> List Cmd.Type
    =     \(c : Config.Type)
      ->    submodulesInit c.submodules
          # binfmtSetup c.arch
          # [ Cmd.run "./buildkite/scripts/docker/load_from_cache.sh ${c.image}"
            , FixPermissions.command c.arch
            ]
          # [ Cmd.runInDocker
                Cmd.Docker::{
                , image = c.image
                , extraEnv = c.environment
                , platform = Arch.platform c.arch
                }
                c.innerScript
            ]

let imageFor
    :     Arch.Type
      ->  { bookworm : Text
          , bullseye : Text
          , jammy : Text
          , noble : Text
          , focal : Text
          }
    =     \(arch : Arch.Type)
      ->  { bookworm =
              merge
                { Amd64 = ContainerImages.minaToolchainBookworm.amd64
                , Arm64 = ContainerImages.minaToolchainBookworm.arm64
                }
                arch
          , bullseye = ContainerImages.minaToolchainBullseye.amd64
          , jammy = ContainerImages.minaToolchainJammy.amd64
          , noble = ContainerImages.minaToolchainNoble.amd64
          , focal = ContainerImages.minaToolchain
          }

let runInToolchain
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            Config::{
            , image = ContainerImages.minaToolchain
            , environment = environment
            , innerScript = innerScript
            }

let runInToolchainNoble
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            Config::{
            , image = ContainerImages.minaToolchainNoble.amd64
            , environment = environment
            , innerScript = innerScript
            }

let runInToolchainJammy
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            Config::{
            , image = ContainerImages.minaToolchainJammy.amd64
            , environment = environment
            , innerScript = innerScript
            }

let runInToolchainBookworm
    : Arch.Type -> List Text -> Text -> List Cmd.Type
    =     \(arch : Arch.Type)
      ->  \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            Config::{
            , image = (imageFor arch).bookworm
            , arch = arch
            , environment = environment
            , innerScript = innerScript
            }

let runInToolchainBullseye
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            Config::{
            , image = ContainerImages.minaToolchainBullseye.amd64
            , environment = environment
            , innerScript = innerScript
            }

let runInToolchainWithSubmodules
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            Config::{
            , submodules = True
            , image = ContainerImages.minaToolchain
            , environment = environment
            , innerScript = innerScript
            }

let runInToolchainNobleWithSubmodules
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            Config::{
            , submodules = True
            , image = ContainerImages.minaToolchainNoble.amd64
            , environment = environment
            , innerScript = innerScript
            }

in  { Config = Config
    , imageFor = imageFor
    , runInToolchain = runInToolchain
    , runInToolchainWithSubmodules = runInToolchainWithSubmodules
    , runInToolchainNobleWithSubmodules = runInToolchainNobleWithSubmodules
    , runInToolchainImage = runInToolchainImage
    , runInToolchainNoble = runInToolchainNoble
    , runInToolchainBookworm = runInToolchainBookworm
    , runInToolchainBullseye = runInToolchainBullseye
    , runInToolchainJammy = runInToolchainJammy
    }
