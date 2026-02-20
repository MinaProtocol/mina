let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let S = ../Lib/SelectFiles.dhall

let DockerImage = ../Command/DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Arch = ../Constants/Arch.dhall

let toolchainPipeline =
          \(spec : DockerImage.ReleaseSpec.Type)
      ->  Pipeline.build
            Pipeline.Config::{
            , spec = JobSpec::{
              , dirtyWhen =
                [ S.strictlyStart (S.contains "dockerfiles/stages/1-")
                , S.strictlyStart (S.contains "dockerfiles/stages/2-")
                , S.strictlyStart (S.contains "dockerfiles/stages/3-")
                , S.strictlyStart
                    ( S.contains
                        "buildkite/src/Jobs/Release/MinaToolchainArtifact"
                    )
                , S.strictly (S.contains "opam.export")
                , S.strictlyEnd (S.contains "rust-toolchain.toml")
                ]
              , path = "Release"
              , name =
                  "MinaToolchainArtifact${DebianVersions.capitalName
                                            spec.deb_codename}${Arch.nameSuffix
                                                                  spec.arch}"
              , tags = [ PipelineTag.Type.Toolchain ]
              }
            , steps = [ DockerImage.generateStep spec ]
            }

in  { pipeline = toolchainPipeline }
