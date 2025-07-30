let PromotePackages = ../Command/Promotion/PromotePackages.dhall

let VerifyPackages = ../Command/Promotion/VerifyPackages.dhall

let Package = ../Constants/DebianPackage.dhall

let Profile = ../Constants/Profiles.dhall

let Artifact = ../Constants/Artifacts.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Network = ../Constants/Network.dhall

let Command = ../Command/Base.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let Pipeline = ../Pipeline/Dsl.dhall

let PipelineMode = ../Pipeline/Mode.dhall

let promote_artifacts =
          \(debians : List Package.Type)
      ->  \(dockers : List Artifact.Type)
      ->  \(version : Text)
      ->  \(new_version : Text)
      ->  \(architecture : Text)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  \(codenames : List DebianVersions.DebVersion)
      ->  \(from_channel : DebianChannel.Type)
      ->  \(to_channel : DebianChannel.Type)
      ->  \(from_repo : DebianRepo.Type)
      ->  \(to_repo : DebianRepo.Type)
      ->  \(tag : Text)
      ->  \(remove_profile_from_name : Bool)
      ->  \(publish : Bool)
      ->  let promotePackages =
                PromotePackages.PromotePackagesSpec::{
                , debians = debians
                , dockers = dockers
                , version = version
                , architecture = architecture
                , new_debian_version = new_version
                , source_debian_repo = from_repo
                , target_debian_repo = to_repo
                , profile = profile
                , network = network
                , codenames = codenames
                , from_channel = from_channel
                , to_channel = to_channel
                , new_tags = [ tag ]
                , remove_profile_from_name = remove_profile_from_name
                , publish = publish
                }

          let debiansSpecs =
                PromotePackages.promotePackagesToDebianSpecs promotePackages

          let dockersSpecs =
                PromotePackages.promotePackagesToDockerSpecs promotePackages

          let pipelineType =
                Pipeline.build
                  ( PromotePackages.promotePipeline
                      debiansSpecs
                      dockersSpecs
                      DebianVersions.DebVersion.Bullseye
                      PipelineMode.Type.Stable
                      ([] : List Command.TaggedKey.Type)
                  )

          in  pipelineType.pipeline

let verify_artifacts =
          \(debians : List Package.Type)
      ->  \(dockers : List Artifact.Type)
      ->  \(new_version : Text)
      ->  \(profile : Profile.Type)
      ->  \(network : Network.Type)
      ->  \(codenames : List DebianVersions.DebVersion)
      ->  \(to_channel : DebianChannel.Type)
      ->  \(repo : DebianRepo.Type)
      ->  \(tag : Text)
      ->  \(remove_profile_from_name : Bool)
      ->  \(publish : Bool)
      ->  let verify_packages =
                VerifyPackages.VerifyPackagesSpec::{
                , promote_step_name = None Text
                , debians = debians
                , dockers = dockers
                , new_debian_version = new_version
                , debian_repo = repo
                , profile = profile
                , network = network
                , codenames = codenames
                , channel = to_channel
                , new_tags = [ tag ]
                , remove_profile_from_name = remove_profile_from_name
                , published = publish
                }

          let debiansSpecs =
                VerifyPackages.verifyPackagesToDebianSpecs verify_packages

          let dockersSpecs =
                VerifyPackages.verifyPackagesToDockerSpecs verify_packages

          let pipelineType =
                Pipeline.build
                  ( VerifyPackages.verifyPipeline
                      debiansSpecs
                      dockersSpecs
                      DebianVersions.DebVersion.Bullseye
                      PipelineMode.Type.Stable
                  )

          in  pipelineType.pipeline

in  { promote_artifacts = promote_artifacts
    , verify_artifacts = verify_artifacts
    }
