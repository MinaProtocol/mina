let S = ../../Lib/SelectFiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let Network = ../../Constants/Network.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let VerifyDockers = ../../Command/Packages/VerifyDockers.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "TearDown"
        , tags = [ PipelineTag.Type.TearDown ]
        , name = "VerifyDockers"
        }
      , steps =
        [ VerifyDockers.verify
            VerifyDockers.Spec::{
            , artifacts =
              [ Artifacts.Type.Daemon
              , Artifacts.Type.Archive
              , Artifacts.Type.Rosetta
              ]
            , networks = [ Network.Type.Devnet, Network.Type.Mainnet ]
            , source_version = "\\\${MINA_DOCKER_TAG}"
            , codenames =
              [ DebianVersions.DebVersion.Bullseye
              , DebianVersions.DebVersion.Focal
              , DebianVersions.DebVersion.Noble
              , DebianVersions.DebVersion.Bookworm
              ]
            }
        ]
      }
