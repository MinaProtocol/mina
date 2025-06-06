let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Network = ../../Constants/Network.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

in  Pipeline.build
      ( ArtifactPipelines.onlyDebianPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts = [ Artifacts.Type.Daemon ]
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            ]
          , network = Network.Type.DevnetLegacy
          , debVersion = DebianVersions.DebVersion.Focal
          , if = Some "build.branch == 'dkijania/build_legacy_debian_on_comp'"
          }
      )
