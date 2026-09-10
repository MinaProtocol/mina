let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

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
            , Artifacts.Type.TestExecutive
            , Artifacts.Type.TxTools
            , Artifacts.Type.DaemonStorageToolbox
            , Artifacts.Type.FunctionalTestSuite
            ]
          , generic = True
          , tags =
            [ PipelineTag.Type.Packaging
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Rosetta
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Mainnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
