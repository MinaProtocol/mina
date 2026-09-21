-- Build specs shared by each debian job and its docker sibling.
--
-- A MinaArtifact job is split in two: Jobs/Release/MinaArtifact<X>.dhall builds
-- the debian packages, Jobs/Release/MinaArtifact<X>Dockers.dhall builds the
-- images from those packages. Both need the same artifact list -- the debian
-- job to know what to package, the docker job to know what to containerise --
-- so the spec lives here once instead of being copied into both files and
-- drifting.

let ArtifactPipelines = ./MinaArtifact.dhall

let Artifacts = ../Constants/Artifacts.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Profiles = ../Constants/Profiles.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let Network = ../Constants/Network.dhall

let PipelineScope = ../Pipeline/Scope.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let bookwormDevnetDevnet =
      ArtifactPipelines.MinaBuildSpec::{
      , artifacts =
        [ Artifacts.Type.Daemon
        , Artifacts.Type.DaemonAppsOnly
        , Artifacts.Type.DaemonConfig
        , Artifacts.Type.DaemonAutoHardfork
        , Artifacts.Type.DaemonAutomode
        , Artifacts.Type.DaemonPrefork
        , Artifacts.Type.CreatePreforkGenesis
        , Artifacts.Type.LogProc
        , Artifacts.Type.Archive
        , Artifacts.Type.Rosetta
        , Artifacts.Type.TestExecutive
        , Artifacts.Type.RosettaAppsOnly
        , Artifacts.Type.ZkappTestTransaction
        , Artifacts.Type.DelegationVerifier
        , Artifacts.Type.DaemonStorageToolbox
        ]
      , tags =
        [ PipelineTag.Type.Long
        , PipelineTag.Type.Release
        , PipelineTag.Type.Docker
        , PipelineTag.Type.Rosetta
        , PipelineTag.Type.Devnet
        , PipelineTag.Type.Amd64
        , PipelineTag.Type.Bookworm
        ]
      }

let bookwormDevnetDevnetInstrumented =
      ArtifactPipelines.MinaBuildSpec::{
      , artifacts =
        [ Artifacts.Type.Daemon
        , Artifacts.Type.DaemonAppsOnly
        , Artifacts.Type.DaemonConfig
        , Artifacts.Type.LogProc
        , Artifacts.Type.Archive
        , Artifacts.Type.Rosetta
        , Artifacts.Type.RosettaAppsOnly
        , Artifacts.Type.ZkappTestTransaction
        , Artifacts.Type.FunctionalTestSuite
        , Artifacts.Type.CreatePreforkGenesis
        , Artifacts.Type.DaemonStorageToolbox
        ]
      , buildFlags = BuildFlags.Type.Instrumented
      , tags =
        [ PipelineTag.Type.Long
        , PipelineTag.Type.Release
        , PipelineTag.Type.Docker
        , PipelineTag.Type.Devnet
        , PipelineTag.Type.Amd64
        , PipelineTag.Type.Bookworm
        ]
      }

let bookwormDevnetLightnet =
      ArtifactPipelines.MinaBuildSpec::{
      , artifacts =
        [ Artifacts.Type.DaemonAppsOnly
        , Artifacts.Type.CreatePreforkGenesis
        , Artifacts.Type.DaemonStorageToolbox
        , Artifacts.Type.LogProc
        ]
      , profile = Profiles.Type.Lightnet
      , tags =
        [ PipelineTag.Type.Long
        , PipelineTag.Type.Release
        , PipelineTag.Type.Docker
        , PipelineTag.Type.Lightnet
        , PipelineTag.Type.Amd64
        , PipelineTag.Type.Bookworm
        ]
      }

let bookwormMainnetMainnet =
      ArtifactPipelines.MinaBuildSpec::{
      , artifacts =
        [ Artifacts.Type.Daemon
        , Artifacts.Type.CreatePreforkGenesis
        , Artifacts.Type.DaemonAppsOnly
        , Artifacts.Type.DaemonConfig
        , Artifacts.Type.DaemonAutoHardfork
        , Artifacts.Type.DaemonAutomode
        , Artifacts.Type.DaemonPrefork
        , Artifacts.Type.LogProc
        , Artifacts.Type.Archive
        , Artifacts.Type.Rosetta
        , Artifacts.Type.RosettaAppsOnly
        , Artifacts.Type.ZkappTestTransaction
        , Artifacts.Type.DaemonStorageToolbox
        ]
      , debVersion = DebianVersions.DebVersion.Bookworm
      , network = Network.Type.Mainnet
      , tags =
        [ PipelineTag.Type.Long
        , PipelineTag.Type.Release
        , PipelineTag.Type.Stable
        , PipelineTag.Type.Mainnet
        , PipelineTag.Type.Amd64
        , PipelineTag.Type.Bookworm
        ]
      , profile = Profiles.Type.Mainnet
      , scope =
        [ PipelineScope.Type.MainlineNightly, PipelineScope.Type.Release ]
      }

in  { bookwormDevnetDevnet = bookwormDevnetDevnet
    , bookwormDevnetDevnetInstrumented = bookwormDevnetDevnetInstrumented
    , bookwormDevnetLightnet = bookwormDevnetLightnet
    , bookwormMainnetMainnet = bookwormMainnetMainnet
    }
