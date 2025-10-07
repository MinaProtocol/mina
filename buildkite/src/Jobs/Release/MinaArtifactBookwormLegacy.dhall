let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

in  Pipeline.build
      ( ArtifactPipelines.onlyDebianPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts = [ Artifacts.Type.DaemonBase, Artifacts.Type.Daemon ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            ]
          , network = Network.Type.Legacy
          , debVersion = DebianVersions.DebVersion.Bookworm
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
