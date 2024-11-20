let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Network = ../../Constants/Network.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.BatchTxn
            , Artifacts.Type.Rosetta
            , Artifacts.Type.ZkappTestTransaction
            ]
          , debVersion = DebianVersions.DebVersion.Focal
          , networks = [ Network.Type.Devnet ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Stable
            ]
          , mode = PipelineMode.Type.Stable
          , prefix = "MinaArtifactDevnet"
          }
      )
