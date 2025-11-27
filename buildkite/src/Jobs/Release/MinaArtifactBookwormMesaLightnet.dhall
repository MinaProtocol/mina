let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let Mesa = ../../Lib/Mesa.dhall

let Expr = ../../Pipeline/Expr.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts = [ Artifacts.Type.LogProc, Artifacts.Type.Daemon ]
          , network = Network.Type.Mesa
          , profile = Profiles.Type.Lightnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bookworm
            , PipelineTag.Type.Lightnet
            ]
          , debVersion = DebianVersions.DebVersion.Bookworm
          , excludeIf = [] : List Expr.Type
          , includeIf = [ Mesa.forMesa ]
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
