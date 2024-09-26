let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

in  Pipeline.build
      ( ArtifactPipelines.onlyDebianPipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.BatchTxn
            , Artifacts.Type.TestExecutive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.FunctionalTestSuite
            ]
          , tags = [ PipelineTag.Type.Debian ]
          , channel = DebianChannel.Type.Experimental
          , prefix = "MinaArtifactOnlyDebian"
          }
      )
