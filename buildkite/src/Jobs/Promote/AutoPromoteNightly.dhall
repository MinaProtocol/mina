-- Auto Promote Nightly is job which should be either used just after nightly run or in separate pipeline
-- Small trick to allow manual override of source version which is about to be promoted
-- If FROM_VERSION_MANUAL is set the used it.
-- Otherwise use MINA_DEB_VERSION which is set in export-git-env-vars.sh file


let S = ../../Lib/SelectFiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DebianPackage = ../../Constants/DebianPackage.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PromotePackages = ../../Command/Promotion/PromotePackages.dhall

let VerifyPackages = ../../Command/Promotion/VerifyPackages.dhall

let pipelineName = "AutoPromoteNightly"

let currentDate = "\\\$(date \"+%Y%m%d\")"

let new_tags =
          \(codename : DebianVersions.DebVersion)
      ->  \(channel : DebianChannel.Type)
      ->  \(repo : DebianRepo.Type)
      ->  [ "latest-${DebianChannel.lowerName channel}-${DebianRepo.shortName
                                                           repo}"
          ]

let promotePackages =
      PromotePackages.PromotePackagesSpec::{
      , debians =
        [ DebianPackage.Type.LogProc
        , DebianPackage.Type.Daemon
        , DebianPackage.Type.Archive
        ]
      , dockers = [ Artifacts.Type.Daemon, Artifacts.Type.Archive ]
      , version = "\\\${FROM_VERSION_MANUAL:-\\\${MINA_DEB_VERSION}}"
      , architecture = "amd64"
      , new_debian_version = currentDate
      , profile = Profiles.Type.Standard
      , network = Network.Type.Devnet
      , codenames =
        [ DebianVersions.DebVersion.Bullseye, DebianVersions.DebVersion.Focal ]
      , from_channel = DebianChannel.Type.Unstable
      , to_channel = DebianChannel.Type.Compatible
      , source_debian_repo = DebianRepo.Type.PackagesO1Test
      , new_tags = new_tags
      , target_debian_repo = DebianRepo.Type.Nightly
      , remove_profile_from_name = False
      , publish = False
      , depends_on =
        [ { name = "PublishDebians", key = "publish-focal-deb-pkg" } ]
      }

let verifyPackages =
          \(pipelineName : Text)
      ->  \(promote_packages : PromotePackages.PromotePackagesSpec.Type)
      ->  VerifyPackages.VerifyPackagesSpec::{
          , promote_step_name = Some pipelineName
          , debians = promote_packages.debians
          , dockers = promote_packages.dockers
          , new_debian_version = promote_packages.new_debian_version
          , profile = promote_packages.profile
          , network = promote_packages.network
          , codenames = promote_packages.codenames
          , channel = promote_packages.to_channel
          , repo = promote_packages.target_debian_repo
          , tags = new_tags
          , remove_profile_from_name = promote_packages.remove_profile_from_name
          , published = promote_packages.publish
          }

let promoteDebiansSpecs =
      PromotePackages.promotePackagesToDebianSpecs promotePackages

let promoteDockersSpecs =
      PromotePackages.promotePackagesToDockerSpecs promotePackages

let verifyDebiansSpecs =
      VerifyPackages.verifyPackagesToDebianSpecs
        (verifyPackages pipelineName promotePackages)

let verifyDockersSpecs =
      VerifyPackages.verifyPackagesToDockerSpecs
        (verifyPackages pipelineName promotePackages)

let steps =
        PromotePackages.promoteSteps
          promoteDebiansSpecs
          promoteDockersSpecs
          pipelineName
          promotePackages.depends_on
      # VerifyPackages.verificationSteps verifyDebiansSpecs verifyDockersSpecs

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Promote"
        , tags = [ PipelineTag.Type.Promote ]
        , name = pipelineName
        }
      , steps = steps
      }
