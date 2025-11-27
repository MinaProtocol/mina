let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Arch = ../../Constants/Arch.dhall

let Expr = ../../Pipeline/Expr.dhall

let Mesa = ../../Lib/Mesa.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.LogProc
            , Artifacts.Type.Daemon
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.CreateLegacyGenesis
            ]
          , network = Network.Type.Mesa
          , arch = Arch.Type.Arm64
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Arm64
            , PipelineTag.Type.Bookworm
            , PipelineTag.Type.Devnet
            ]
          , debVersion = DebianVersions.DebVersion.Bookworm
          , excludeIf = [] : List Expr.Type
          , includeIf = [ Mesa.forMesa ]
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
