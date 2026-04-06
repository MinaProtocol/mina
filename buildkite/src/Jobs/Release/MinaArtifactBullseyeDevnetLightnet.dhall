let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetDevnet.dhall
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonAppsOnly
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.DaemonPrefork
            , Artifacts.Type.CreatePreforkGenesis
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.TestExecutive
            , Artifacts.Type.RosettaAppsOnly
            , Artifacts.Type.ZkappTestTransaction
========
            [ Artifacts.Type.DaemonAppsOnly
            , Artifacts.Type.CreatePreforkGenesis
            , Artifacts.Type.DaemonStorageToolbox
            , Artifacts.Type.LogProc
>>>>>>>> develop:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetLightnet.dhall
            ]
          , profile = Profiles.Type.Lightnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetDevnet.dhall
            , PipelineTag.Type.Rosetta
            , PipelineTag.Type.Devnet
========
            , PipelineTag.Type.Lightnet
>>>>>>>> develop:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetLightnet.dhall
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          }
      )
