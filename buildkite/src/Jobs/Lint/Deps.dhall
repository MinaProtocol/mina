let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let B = ../../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let ContainerImages = ../../Constants/ContainerImages.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/")
          , S.strictlyStart (S.contains "maintenance/deps")
          , S.strictly (S.contains "Makefile")
          , S.exactly "buildkite/src/Jobs/Lint/Deps" "dhall"
          ]
        , path = "Lint"
        , name = "Deps"
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
                  RunInToolchain.Config::{
                  , submodules = True
                  , image = ContainerImages.minaToolchainNoble.amd64
                  , innerScript =
                          "make deps-advice | tee deps-advice.txt ; "
                      ++  "make check-deps"
                  }
            , label = "Dependency graph: budget, layering, unused deps"
            , key = "check-deps"
            , target = Size.Multi
            , soft_fail = Some (B/SoftFail.Boolean True)
            , docker = None Docker.Type
            , artifact_paths = [ S.contains "deps-advice.txt" ]
            }
        ]
      }
