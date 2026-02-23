let S = ../Lib/SelectFiles.dhall

let PublishPackages = ../Command/Packages/Publish.dhall

let Profile = ../Constants/Profiles.dhall

let Artifact = ../Constants/Artifacts.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Network = ../Constants/Network.dhall

let JobSpec = ../Pipeline/JobSpec.dhall

let PipelineTag = ../Pipeline/Tag.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let DockerRepo = ../Constants/DockerRepo.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let promote_artifacts =
          \(artifacts : List Artifact.Type)
      ->  \(version : Text)
      ->  \(new_version : Text)
      ->  \(architecture : Text)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  \(codenames : List DebianVersions.DebVersion)
      ->  \(channel : DebianChannel.Type)
      ->  \(repo : DebianRepo.Type)
      ->  \(docker_repo : DockerRepo.Type)
      ->  \(verify : Bool)
      ->  \(build_id : Text)
      ->  let spec =
                PublishPackages.Spec::{
                , artifacts = artifacts
                , profile = profile
                , networks = [ network ]
                , codenames = codenames
                , channel = channel
                , docker_repo = docker_repo
                , backend = "local"
                , verify = True
                , source_version = version
                , build_id = build_id
                , new_docker_tags =
                        \(codename : DebianVersions.DebVersion)
                    ->  \(channel : DebianChannel.Type)
                    ->  \(branch : Text)
                    ->  \(profile : Profile.Type)
                    ->  \(commit : Text)
                    ->  \(latestGitTag : Text)
                    ->  \(todayDate : Text)
                    ->  [ "${new_version}" ]
                , target_version =
                        \(codename : DebianVersions.DebVersion)
                    ->  \(channel : DebianChannel.Type)
                    ->  \(branch : Text)
                    ->  \(profile : Profile.Type)
                    ->  \(commit : Text)
                    ->  \(latestGitTag : Text)
                    ->  \(todayDate : Text)
                    ->  "${new_version}"
                }

          let pipeline =
                Pipeline.build
                  Pipeline.Config::{
                  , spec = JobSpec::{
                    , dirtyWhen = [ S.everything ]
                    , path = "Publish"
                    , tags = [] : List PipelineTag.Type
                    , name = "PublishPackages"
                    }
                  , steps = PublishPackages.publish spec
                  }

          in  pipeline.pipeline

in  { promote_artifacts = promote_artifacts }
