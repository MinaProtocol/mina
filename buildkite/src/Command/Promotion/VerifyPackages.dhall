let Prelude = ../../External/Prelude.dhall

let Optional/toList = Prelude.Optional.toList

let Optional/map = Prelude.Optional.map

let List/map = Prelude.List.map

let Package = ../../Constants/DebianPackage.dhall

let Network = ../../Constants/Network.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifact = ../../Constants/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Command = ../Base.dhall

let VerifyDebian = ./VerifyDebian.dhall

let VerifyDocker = ./VerifyDocker.dhall

let PromoteDebian = ./PromoteDebian.dhall

let PromoteDocker = ./PromoteDocker.dhall

let VerifyPackagesSpec =
      { Type =
          { promote_step_name : Optional Text
          , debians : List Package.Type
          , dockers : List Artifact.Type
          , new_debian_version : Text
          , profile : Profiles.Type
          , network : Network.Type
          , codenames : List DebianVersions.DebVersion
          , channel : DebianChannel.Type
          , new_tags : List Text
          , remove_profile_from_name : Bool
          , published : Bool
          }
      , default =
          { promote_step_name = None
          , debians = [] : List Package.Type
          , dockers = [] : List Artifact.Type
          , new_debian_version = "\\\\\$MINA_DEB_VERSION"
          , profile = Profiles.Type.Standard
          , network = Network.Type.Mainnet
          , codenames = [] : List DebianVersions.DebVersion
          , channel = DebianChannel.Type.Compatible
          , new_tags = [] : List Text
          , remove_profile_from_name = False
          , published = False
          }
      }

let verifyPackagesToDockerSpecs
    : VerifyPackagesSpec.Type -> List PromoteDocker.PromoteDockerSpec.Type
    =     \(verify_packages : VerifyPackagesSpec.Type)
      ->  let dockers_spec =
                List/map
                  Artifact.Type
                  (List PromoteDocker.PromoteDockerSpec.Type)
                  (     \(docker : Artifact.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDocker.PromoteDockerSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDocker.PromoteDockerSpec::{
                                , profile = verify_packages.profile
                                , name = docker
                                , codename = codename
                                , new_tags = verify_packages.new_tags
                                , network = verify_packages.network
                                , publish = verify_packages.published
                                , remove_profile_from_name =
                                    verify_packages.remove_profile_from_name
                                , deps =
                                    Optional/toList
                                      Command.TaggedKey.Type
                                      ( Optional/map
                                          Text
                                          Command.TaggedKey.Type
                                          (     \(name : Text)
                                            ->  { name = name
                                                , key =
                                                    "add-tag-to-${Artifact.lowerName
                                                                    docker}-${DebianVersions.lowerName
                                                                                codename}-docker"
                                                }
                                          )
                                          verify_packages.promote_step_name
                                      )
                                , step_key =
                                    "verify-tag-${Artifact.lowerName
                                                    docker}-${DebianVersions.lowerName
                                                                codename}-docker"
                                }
                          )
                          verify_packages.codenames
                  )
                  verify_packages.dockers

          in  Prelude.List.fold
                (List PromoteDocker.PromoteDockerSpec.Type)
                dockers_spec
                (List PromoteDocker.PromoteDockerSpec.Type)
                (     \(a : List PromoteDocker.PromoteDockerSpec.Type)
                  ->  \(b : List PromoteDocker.PromoteDockerSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDocker.PromoteDockerSpec.Type)

let verifyPackagesToDebianSpecs
    : VerifyPackagesSpec.Type -> List PromoteDebian.PromoteDebianSpec.Type
    =     \(verify_packages : VerifyPackagesSpec.Type)
      ->  let debians_spec =
                List/map
                  Package.Type
                  (List PromoteDebian.PromoteDebianSpec.Type)
                  (     \(debian : Package.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDebian.PromoteDebianSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDebian.PromoteDebianSpec::{
                                , profile = verify_packages.profile
                                , package = debian
                                , new_version =
                                    verify_packages.new_debian_version
                                , network = verify_packages.network
                                , codename = codename
                                , to_channel = verify_packages.channel
                                , remove_profile_from_name =
                                    verify_packages.remove_profile_from_name
                                , deps =
                                    Optional/toList
                                      Command.TaggedKey.Type
                                      ( Optional/map
                                          Text
                                          Command.TaggedKey.Type
                                          (     \(name : Text)
                                            ->  { name = name
                                                , key =
                                                    "promote-debian-${Package.lowerName
                                                                        debian}-${DebianVersions.lowerName
                                                                                    codename}-to-${DebianChannel.lowerName
                                                                                                     verify_packages.channel}"
                                                }
                                          )
                                          verify_packages.promote_step_name
                                      )
                                , step_key =
                                    "verify-promote-debian-${Package.lowerName
                                                               debian}-${DebianVersions.lowerName
                                                                           codename}-to-${DebianChannel.lowerName
                                                                                            verify_packages.channel}"
                                }
                          )
                          verify_packages.codenames
                  )
                  verify_packages.debians

          in  Prelude.List.fold
                (List PromoteDebian.PromoteDebianSpec.Type)
                debians_spec
                (List PromoteDebian.PromoteDebianSpec.Type)
                (     \(a : List PromoteDebian.PromoteDebianSpec.Type)
                  ->  \(b : List PromoteDebian.PromoteDebianSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDebian.PromoteDebianSpec.Type)

let verificationSteps
    :     List PromoteDebian.PromoteDebianSpec.Type
      ->  List PromoteDocker.PromoteDockerSpec.Type
      ->  List Command.Type
    =     \(debians_spec : List PromoteDebian.PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDocker.PromoteDockerSpec.Type)
      ->    List/map
              PromoteDebian.PromoteDebianSpec.Type
              Command.Type
              (     \(spec : PromoteDebian.PromoteDebianSpec.Type)
                ->  VerifyDebian.promoteDebianVerificationStep spec
              )
              debians_spec
          # List/map
              PromoteDocker.PromoteDockerSpec.Type
              Command.Type
              (     \(spec : PromoteDocker.PromoteDockerSpec.Type)
                ->  VerifyDocker.promoteDockerVerificationStep spec
              )
              dockers_spec

let verifyPipeline
    :     List PromoteDebian.PromoteDebianSpec.Type
      ->  List PromoteDocker.PromoteDockerSpec.Type
      ->  DebianVersions.DebVersion
      ->  PipelineMode.Type
      ->  Pipeline.Config.Type
    =     \(debians_spec : List PromoteDebian.PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDocker.PromoteDockerSpec.Type)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  \(mode : PipelineMode.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen debVersion
            , path = "Release"
            , name = "VerifyPackage"
            , tags = [] : List PipelineTag.Type
            , mode = mode
            }
          , steps = verificationSteps debians_spec dockers_spec
          }

in  { VerifyPackagesSpec = VerifyPackagesSpec
    , verifyPackagesToDockerSpecs = verifyPackagesToDockerSpecs
    , verifyPackagesToDebianSpecs = verifyPackagesToDebianSpecs
    , verificationSteps = verificationSteps
    , verifyPipeline = verifyPipeline
    }
