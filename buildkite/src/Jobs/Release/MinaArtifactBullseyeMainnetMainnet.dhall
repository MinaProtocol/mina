let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Profiles = ../../Constants/Profiles.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonAppsOnly
<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetLightnet.dhall
            , Artifacts.Type.CreatePreforkGenesis
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.LogProc
========
            , Artifacts.Type.DaemonAutoHardfork
            , Artifacts.Type.DaemonAutomode
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.DaemonPrefork
            , Artifacts.Type.LogProc
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            , Artifacts.Type.RosettaAppsOnly
            , Artifacts.Type.ZkappTestTransaction
            , Artifacts.Type.CreatePreforkGenesis
            , Artifacts.Type.DaemonStorageToolbox
>>>>>>>> mesa/pass-o1js-ci:buildkite/src/Jobs/Release/MinaArtifactBullseyeMainnetMainnet.dhall
            ]
          , profile = Profiles.Type.Lightnet
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetLightnet.dhall
            , PipelineTag.Type.Docker
            , PipelineTag.Type.Lightnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
========
            , PipelineTag.Type.Stable
            , PipelineTag.Type.Rosetta
            , PipelineTag.Type.Mainnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
            ]
          , profile = Profiles.Type.Mainnet
          , scope =
            [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
>>>>>>>> mesa/pass-o1js-ci:buildkite/src/Jobs/Release/MinaArtifactBullseyeMainnetMainnet.dhall
          }
      )
