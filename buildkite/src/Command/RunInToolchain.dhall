-- Helpers for running a command inside the mina toolchain docker image.
--
-- Everything funnels through `runInToolchain`, which takes a `Config` and is the
-- only real entrypoint; a call site sets just the fields that differ from the
-- defaults (default image, amd64, no submodules).
--
-- `runInDefaultToolchain` is the shorthand for the common case -- default image,
-- amd64, no submodules -- where all a job wants to hand over is env + script.
-- Standard jobs should use it; reach for `runInToolchain` only when something
-- actually differs (a different image, arm64, submodules).
--
-- Submodules: most CI jobs (lint, dhall checks, tests that run against prebuilt
-- artifacts) never read submodule contents, so submodule init is OPT-IN --
-- `Config.default` sets `submodules = False`. Jobs that build code from source
-- (proof-systems/snarky are linked into the OCaml build) must pass
-- `submodules = True`; Toolchain.select threads the same flag for artifact
-- builds.
--
-- The opt-in lives at the command level rather than in each step's env because
-- BUILDKITE_GIT_SUBMODULES is a protected, build-level variable: Buildkite
-- ignores it when set from a step, so submodule checkout cannot be turned off
-- per-job from the pipeline. It can only be turned off for the whole agent, and
-- then re-enabled explicitly by the jobs that need it.
--
-- That agent-side default has NOT been flipped yet. Until it is, agents still
-- auto-checkout submodules and the opt-in is merely redundant (build jobs
-- re-init an already-initialized tree); the savings land once agents stop
-- checking out submodules by default. Keep the opt-ins correct in the meantime,
-- since they become load-bearing the moment that switch is thrown.

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
          , image = ContainerImages.minaToolchain
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

          then  [ Cmd.run "git submodule sync --recursive"
                , Cmd.run
                    "git submodule update --init --recursive --depth 1 --single-branch --jobs \"\$(nproc)\""
                ]

          else  [] : List Cmd.Type

let runInToolchain
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

let runInDefaultToolchain
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchain
            Config::{ environment = environment, innerScript = innerScript }

in  { Config = Config
    , runInToolchain = runInToolchain
    , runInDefaultToolchain = runInDefaultToolchain
    }
