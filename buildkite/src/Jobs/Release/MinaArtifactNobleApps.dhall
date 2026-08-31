let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

in  Pipeline.build
      ( ArtifactPipelines.appsPipeline
          ArtifactPipelines.AppsSpec::{
          , debVersion = DebianVersions.DebVersion.Noble
          , extraBuildEnvs = [ "MINA_BUILD_PORTABLE=1" ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Noble
            ]
          , scope = [ PipelineScope.Type.Weekly, PipelineScope.Type.Release ]
          }
      )
