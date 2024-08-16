let S = ../../Lib/SelectFiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DebianPackage = ../../Constants/DebianPackage.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PromotePackages = ../../Command/Promotion/PromotePackages.dhall

let VerifyPackages = ../../Command/Promotion/VerifyPackages.dhall

let promotePackages =
      PromotePackages.PromotePackagesSpec::{
      , debians =
        [ DebianPackage.Type.Daemon
        , DebianPackage.Type.LogProc
        , DebianPackage.Type.Archive
        ]
      , dockers = [ Artifacts.Type.Daemon, Artifacts.Type.Archive ]
      , version = "\\\${FROM_VERSION_MANUAL}"
      , architecture = "amd64"
      , new_version = "\\\$(date \"+%Y%m%d\")"
      , profile = Profiles.Type.Standard
      , network = Network.Type.Devnet
      , codenames =
        [ DebianVersions.DebVersion.Bullseye
        , DebianVersions.DebVersion.Focal
        , DebianVersions.DebVersion.Buster
        ]
      , from_channel = DebianChannel.Type.Unstable
      , to_channel = DebianChannel.Type.Nightly
      , tag = "nightly"
      , remove_profile_from_name = True
      , publish = False
      }

let verifyPackages =
      VerifyPackages.VerifyPackagesSpec::{
      , promote_step_name = Some "AutoPromoteNightly"
      , debians =
        [ DebianPackage.Type.Daemon
        , DebianPackage.Type.LogProc
        , DebianPackage.Type.Archive
        ]
      , dockers = [ Artifacts.Type.Daemon, Artifacts.Type.Archive ]
      , new_version = "\\\$(date \"+%Y%m%d\")"
      , profile = Profiles.Type.Standard
      , network = Network.Type.Devnet
      , codenames =
        [ DebianVersions.DebVersion.Bullseye
        , DebianVersions.DebVersion.Focal
        , DebianVersions.DebVersion.Buster
        ]
      , channel = DebianChannel.Type.Nightly
      , tag = "nightly"
      , remove_profile_from_name = True
      , published = False
      }

let promoteDebiansSpecs =
      PromotePackages.promotePackagesToDebianSpecs promotePackages

let promoteDockersSpecs =
      PromotePackages.promotePackagesToDockerSpecs promotePackages

let verifyDebiansSpecs =
      VerifyPackages.verifyPackagesToDebianSpecs verifyPackages

let verifyDockersSpecs =
      VerifyPackages.verifyPackagesToDockerSpecs verifyPackages

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Promote"
        , tags = [ PipelineTag.Type.Promote ]
        , name = "AutoPromoteNightly"
        }
      , steps =
            PromotePackages.promoteSteps promoteDebiansSpecs promoteDockersSpecs
          # VerifyPackages.verificationSteps
              verifyDebiansSpecs
              verifyDockersSpecs
      }
