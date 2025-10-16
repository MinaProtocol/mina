-- Auto Promote Nightly is job which should be either used just after nightly run or in separate pipeline
-- Small trick to allow manual override of source version which is about to be promoted
-- If FROM_VERSION_MANUAL is set the used it.
-- Otherwise use MINA_DEB_VERSION which is set in export-git-env-vars.sh file


let S = ../../Lib/SelectFiles.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Artifacts = ../../Constants/Artifacts.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

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
      ->  "${latestGitTag}-${todayDate}"

let specs_for_branch =
          \(branch : Text)
      ->  \(channel : DebianChannel.Type)
      ->  \(profile : Profiles.Type)
      ->  PublishPackages.Spec::{
          , artifacts =
            [ Artifacts.Type.LogProc
            , Artifacts.Type.Daemon
            , Artifacts.Type.Archive
            , Artifacts.Type.Rosetta
            ]
          , profile = profile
          , networks = [ Network.Type.Devnet ]
          , codenames =
            [ DebianVersions.DebVersion.Noble
            , DebianVersions.DebVersion.Bookworm
            ]
          , debian_repo = DebianRepo.Type.Nightly
          , channel = channel
          , new_docker_tags = new_tags
          , target_version = targetVersion
          , publish_to_docker_io = False
          , backend = "local"
          , verify = True
          , branch = "\\\${BUILDKITE_BRANCH}"
          , source_version = "\\\${MINA_DEB_VERSION}"
          , build_id = "\\\${BUILDKITE_BUILD_ID}"
          , if_ = Some "build.branch == \"${branch}\""
          }

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen = [ S.everything ]
        , path = "Promote"
        , tags = [ PipelineTag.Type.Promote, PipelineTag.Type.TearDown ]
        , name = "AutoPromoteNightly"
        , scope = [ PipelineScope.Type.MainlineNightly ]
        }
      , steps =
            PublishPackages.publish
              ( specs_for_branch
                  "dkijania/add_missing_configurations"
                  DebianChannel.Type.Compatible
                  Profiles.Type.Lightnet
              )
          # PublishPackages.publish
              ( specs_for_branch
                  "develop"
                  DebianChannel.Type.Develop
                  Profiles.Type.Lightnet
              )
          # PublishPackages.publish
              ( specs_for_branch
                  "master"
                  DebianChannel.Type.Master
                  Profiles.Type.Lightnet
              )
          # PublishPackages.publish
              ( specs_for_branch
                  "dkijania/add_missing_configurations"
                  DebianChannel.Type.Compatible
                  Profiles.Type.Devnet
              )
          # PublishPackages.publish
              ( specs_for_branch
                  "develop"
                  DebianChannel.Type.Develop
                  Profiles.Type.Devnet
              )
          # PublishPackages.publish
              ( specs_for_branch
                  "master"
                  DebianChannel.Type.Master
                  Profiles.Type.Devnet
              )
      }
