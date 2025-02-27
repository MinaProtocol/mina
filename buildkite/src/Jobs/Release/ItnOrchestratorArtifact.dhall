let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DockerImage = ../../Command/DockerImage.dhall

let Profiles = ../../Constants/Profiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let spec =
      DockerImage.ReleaseSpec::{
      , service = Artifacts.Type.ItnOrchestrator
      , step_key = "itn-orchestrator-docker-image"
      , network = "berkeley"
      , deb_repo = DebianRepo.Type.Local
      , deps =
          DebianVersions.dependsOn
            DebianVersions.DebVersion.Bullseye
            Profiles.Type.Standard
      }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.strictlyStart
              (S.contains "buildkite/src/Jobs/Release/ItnOrchestratorArtifact")
          , S.strictlyStart (S.contains "src/app/itn_orchestrator")
          ]
        , path = "Release"
        , name = "ItnOrchestratorArtifact"
        , tags =
          [ PipelineTag.Type.Long
          , PipelineTag.Type.Release
          , PipelineTag.Type.Stable
          ]
        }
      , steps = [ DockerImage.generateStep spec ]
      }
