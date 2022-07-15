let Prelude = ../../External/Prelude.dhall

let B = ../../External/Buildkite.dhall

let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Size = ../../Command/Size.dhall

let dependsOn = [
    { name = "MinaArtifactBuster", key = "daemon-devnet-buster-docker-image" }
]

in  Pipeline.build
      Pipeline.Config::{
        spec = JobSpec::{
        , dirtyWhen = [
            S.strictlyStart (S.contains "src/")
          ]
        , path = "Lint"
        , name = "Types"
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchainBuster
                  [ "CI=true"
                  , "RELEASE_BRANCH_NAME="
                  , "BRANCH_NAME=\$BUILDKITE_BRANCH"
                  , "BASE_BRANCH_NAME=\$BUILDKITE_PULL_REQUEST_BASE_BRANCH"
                  ]
                  "./buildkite/scripts/lint-type-shapes.sh"
            , depends_on = dependsOn
            , label = "Lint versioned type serialization changes"
            , key = "lint-types"
            , target = Size.Medium
            , docker = None Docker.Type
           }
        ]
      }
