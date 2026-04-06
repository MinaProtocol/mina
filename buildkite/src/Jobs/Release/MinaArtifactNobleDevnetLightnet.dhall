let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Network = ../../Constants/Network.dhall

<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactFocalDevnetDevnet.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
========
let Profiles = ../../Constants/Profiles.dhall
>>>>>>>> develop:buildkite/src/Jobs/Release/MinaArtifactNobleDevnetLightnet.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactFocalDevnetDevnet.dhall
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonAppsOnly
            , Artifacts.Type.DaemonAutoHardfork
            , Artifacts.Type.DaemonPrefork
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.RosettaAppsOnly
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.CreatePreforkGenesis
            ]
          , network = Network.Type.Devnet
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
========
            [ Artifacts.Type.LogProc
            , Artifacts.Type.DaemonAppsOnly
            , Artifacts.Type.DaemonStorageToolbox
            ]
          , network = Network.Type.Devnet
          , profile = Profiles.Type.Lightnet
>>>>>>>> develop:buildkite/src/Jobs/Release/MinaArtifactNobleDevnetLightnet.dhall
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Focal
            ]
          , debVersion = DebianVersions.DebVersion.Noble
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
          }
      )
