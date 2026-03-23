let ArtifactPipelines = ../../Command/MinaArtifact.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactFocalDevnetDevnet.dhall
let Network = ../../Constants/Network.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

========
>>>>>>>> mesa/pass-o1js-ci:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetLightnet.dhall
in  Pipeline.build
      ( ArtifactPipelines.pipeline
          ArtifactPipelines.MinaBuildSpec::{
          , artifacts =
            [ Artifacts.Type.Daemon
            , Artifacts.Type.DaemonAppsOnly
<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactFocalDevnetDevnet.dhall
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
            , Artifacts.Type.CreatePreforkGenesis
            , Artifacts.Type.DaemonConfig
            , Artifacts.Type.LogProc
            ]
          , profile = Profiles.Type.Lightnet
>>>>>>>> mesa/pass-o1js-ci:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetLightnet.dhall
          , tags =
            [ PipelineTag.Type.Long
            , PipelineTag.Type.Release
            , PipelineTag.Type.Docker
<<<<<<<< HEAD:buildkite/src/Jobs/Release/MinaArtifactFocalDevnetDevnet.dhall
            , PipelineTag.Type.Devnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Focal
========
            , PipelineTag.Type.Lightnet
            , PipelineTag.Type.Amd64
            , PipelineTag.Type.Bullseye
>>>>>>>> mesa/pass-o1js-ci:buildkite/src/Jobs/Release/MinaArtifactBullseyeDevnetLightnet.dhall
            ]
          }
      )
