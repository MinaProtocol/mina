let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifact/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Network = ../../Constants/Network.dhall

in  Pipeline.build
      ( ArtifactPipelines.onlyDebianPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon { network = Network.Type.Devnet } ]
          , prefix = "MinaArtifactBenchDaemon"
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
