let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.CreateLegacyGenesis
            ]
          , network = Network.Type.Devnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            ]
          , debVersion = DebianVersions.DebVersion.Noble
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
