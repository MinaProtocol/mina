let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Expr = ../../Pipeline/Expr.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.BatchTxn
            , Artifacts.Type.TestExecutive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.CreateLegacyGenesis
            ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Rosetta
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          , excludeIf = [] : List Expr.Type
          }
      )
