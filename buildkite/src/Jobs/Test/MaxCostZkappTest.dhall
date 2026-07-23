let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Dockers = ../../Constants/DockerVersions.dhall

let Network = ../../Constants/Network.dhall

let Profile = ../../Constants/Profiles.dhall

let MaxCostZkappTest = ../../Command/MaxCostZkappTest.dhall

let dependsOn =
      Dockers.dependsOn
        Dockers.DepsSpec::{
        , network = Network.Type.Devnet
        , profile = Profile.Type.Devnet
        }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "src/lib")
          , S.strictlyStart (S.contains "src/app/cli")
          , S.exactly "scripts/generate-local-genesis" "sh"
          , S.exactly "buildkite/scripts/tests/max-cost-zkapp-test" "sh"
          , S.exactly "buildkite/src/Jobs/Test/MaxCostZkappTest" "dhall"
          , S.exactly "buildkite/src/Command/MaxCostZkappTest" "dhall"
          ]
        , path = "Test"
        , name = "MaxCostZkappTest"
        , tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
        , scope = [ PipelineScope.Type.PullRequest, PipelineScope.Type.Nightly ]
        }
      , steps = [ MaxCostZkappTest.step dependsOn ]
      }
