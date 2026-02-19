let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Network = ../../Constants/Network.dhall

in  Pipeline.build
      ( ArtifactPipelines.onlyDebianPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.BatchTxn
            , Artifacts.Type.TestExecutive
            , Artifacts.Type.Rosetta
            ]
          , tags = [ PipelineTag.Type.Docker ]
          , network = Network.Type.Devnet
          , channel = DebianChannel.Type.Experimental
          , prefix = "MinaArtifactOnlyDebian"
          }
      )
