let Pipeline = ../Pipeline/Dsl.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let S = ../Lib/SelectFiles.dhall

let DockerImage = ../Command/DockerImage.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Arch = ../Constants/Arch.dhall

let basePipeline =
          \(spec : DockerImage.ReleaseSpec.Type)
      ->  Pipeline.build
            Pipeline.Config::{
            , spec = JobSpec::{
              , dirtyWhen =
                [ S.strictlyStart (S.contains "dockerfiles/stages/1-base-deps")
                , S.strictlyStart
                    (S.contains "buildkite/src/Jobs/Release/MinaBaseArtifact")
                , S.exactly "buildkite/src/Command/MinaArtifactBase" "dhall"
                ]
              , path = "Release"
              , name =
                  "MinaBaseArtifact${DebianVersions.capitalName
                                       spec.deb_codename}${Arch.nameSuffix
                                                             spec.arch}"
              , tags = [ PipelineTag.Type.Toolchain ]
              }
            , steps = [ DockerImage.generateStep spec ]
            }

in  { pipeline = basePipeline }
