let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts = [ Artifacts.Type.Daemon, Artifacts.Type.LogProc ]
          , profile = Profiles.Type.Lightnet
          }
      )
