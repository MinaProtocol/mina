let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "flake" "nix"
          , S.exactly "flake" "lock"
          , S.exactly ".gitmodules" ""
          , S.exactly "scripts/check-flake-submodule-sync" "sh"
          , S.exactly "buildkite/src/Jobs/Lint/FlakeSubmoduleSync" "dhall"
          ]
        , path = "Lint"
        , name = "FlakeSubmoduleSync"
        , tags =
          [ PipelineTag.Type.Fast
          , PipelineTag.Type.Lint
          , PipelineTag.Type.Stable
          ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "make check-flake-submodule-sync"
            , label = "Lint: flake input revs match submodule SHAs"
            , key = "check-flake-submodule-sync"
            , target = Size.Multi
            , docker = None Docker.Type
            }
        ]
      }
