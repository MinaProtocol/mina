let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let BuildFlags = ../../Constants/BuildFlags.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

in  Pipeline.build
      ( ArtifactPipelines.packagePipeline
          ArtifactPipelines.PackagingSpec::{
          , artifacts =
            [ Artifacts.Type.DaemonGeneric
            , Artifacts.Type.ArchiveGeneric
            , Artifacts.Type.RosettaGeneric
            , Artifacts.Type.LogProc
            , Artifacts.Type.TxTools
            , Artifacts.Type.FunctionalTestSuite
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , generic = True
          , buildFlags = BuildFlags.Type.Instrumented
          , tags =
            [ PipelineTag.Type.Packaging
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Mainnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
