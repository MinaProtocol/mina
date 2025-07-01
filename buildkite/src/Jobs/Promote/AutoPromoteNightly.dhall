-- Auto Promote Nightly is job which should be either used just after nightly run or in separate pipeline
-- Small trick to allow manual override of source version which is about to be promoted
-- If FROM_VERSION_MANUAL is set the used it.
-- Otherwise use MINA_DEB_VERSION which is set in export-git-env-vars.sh file


let S = ../../Lib/SelectFiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PublishPackages = ../../Command/Packages/Publish.dhall

let new_tags =
          \(codename : DebianVersions.DebVersion)
      ->  \(channel : DebianChannel.Type)
      ->  \(branch : Text)
      ->  \(profile : Profiles.Type)
      ->  \(commit : Text)
      ->  \(latestGitTag : Text)
      ->  \(todayDate : Text)
      ->  [ "latest-${branch}"
          , "${todayDate}-${branch}"
          , "${latestGitTag}.${todayDate}-${branch}"
          ]

let targetVersion =
          \(codename : DebianVersions.DebVersion)
      ->  \(channel : DebianChannel.Type)
      ->  \(branch : Text)
      ->  \(profile : Profiles.Type)
      ->  \(commit : Text)
      ->  \(latestGitTag : Text)
      ->  \(todayDate : Text)
      ->  "${latestGitTag}-${todayDate}-${branch}-${DebianVersions.lowerName
                                                      codename}-${DebianChannel.lowerName
                                                                    channel}"

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Promote"
        , tags = [ PipelineTag.Type.Promote ]
        , name = "AutoPromoteNightly"
        }
      , steps =
          PublishPackages.publish
            PublishPackages.Spec::{
            , artifacts =
              [ Artifacts.Type.Daemon
              , Artifacts.Type.Archive
              , Artifacts.Type.Rosetta
              ]
            , profile = Profiles.Type.Standard
            , networks = [ Network.Type.Devnet ]
            , codenames =
              [ DebianVersions.DebVersion.Bullseye
              , DebianVersions.DebVersion.Focal
              ]
            , channel = DebianChannel.Type.Compatible
            , new_docker_tags = new_tags
            , target_version = targetVersion
            , publish_to_docker_io = False
            , backend = "local"
            , verify = True
            , branch = "\\\${BUILDKITE_BRANCH}"
            , source_version = "\\\${MINA_DOCKER_TAG}"
            , build_id = "\\\${BUILDKITE_BUILD_ID}"
            }
      }
