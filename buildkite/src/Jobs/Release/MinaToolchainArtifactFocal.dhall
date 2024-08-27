let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DockerImage = ../../Command/DockerImage.dhall

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
        , name = "MinaToolchainArtifactFocal"
        , tags = [ PipelineTag.Type.Toolchain ]
        }
      , steps =
        [ let toolchainSpec =
                DockerImage.ReleaseSpec::{
                , service = "mina-toolchain"
                , deb_codename = "focal"
                , no_cache = True
                , step_key = "toolchain-focal-docker-image"
                }

          in  DockerImage.generateStep toolchainSpec
        ]
      }
