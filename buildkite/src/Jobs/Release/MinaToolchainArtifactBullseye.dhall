let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DockerImage = ../../Command/DockerImage.dhall

let Artifacts = ../../Constants/Artifacts.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart (S.contains "dockerfiles/stages/1-")
          , S.strictlyStart (S.contains "dockerfiles/stages/2-")
          , S.strictlyStart (S.contains "dockerfiles/stages/3-")
          , S.strictlyStart
              (S.contains "buildkite/src/Jobs/Release/MinaToolchainArtifact")
          , S.strictly (S.contains "opam.export")
          , S.strictlyEnd (S.contains "rust-toolchain.toml")
          ]
        , path = "Release"
        , name = "MinaToolchainArtifactBullseye"
        , tags = [ PipelineTag.Type.Toolchain ]
        }
      , steps =
        [ let toolchainBullseyeSpec =
                DockerImage.ReleaseSpec::{
                , service = Artifacts.Type.Toolchain
                , deb_codename = "bullseye"
                , no_cache = True
                , step_key = "toolchain-bullseye-docker-image"
                }

          in  DockerImage.generateStep toolchainBullseyeSpec
        ]
      }
