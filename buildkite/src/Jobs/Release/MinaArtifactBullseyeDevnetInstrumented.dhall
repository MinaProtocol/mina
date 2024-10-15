let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            ]
          , buildFlags = BuildFlags.Type.Instrumented
          }
      )
