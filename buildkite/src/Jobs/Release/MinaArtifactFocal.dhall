let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.Archive
            , Artifacts.Type.ArchiveMigration
            , Artifacts.Type.BatchTxn
            , Artifacts.Type.TestExecutive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.ZkappTestTransaction
            ]
          , debVersion = DebianVersions.DebVersion.Focal
          }
      )
