let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Arch = ../../Constants/Arch.dhall

let Mesa = ../../Lib/Mesa.dhall

let Expr = ../../Pipeline/Expr.dhall

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
            , PipelineTag.Type.Noble
            ]
          , excludeIf = [] : List Expr.Type
          , includeIf = [ Mesa.forMesa ]
          , debVersion = DebianVersions.DebVersion.Noble
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
