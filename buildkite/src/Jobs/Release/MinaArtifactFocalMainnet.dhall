let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Network = ../../Constants/Network.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            ]
          , debVersion = DebianVersions.DebVersion.Focal
          , network = Network.Type.Mainnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Stable
            ]
          , mode = PipelineMode.Type.Stable
          }
      )
