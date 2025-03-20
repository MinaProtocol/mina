let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

let Package = ../../Constants/DebianPackage.dhall

let Network = ../../Constants/Network.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DebianChannel = ../../Constants/DebianChannel.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifact = ../../Constants/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let DebianRepo = ../../Constants/DebianRepo.dhall

let PromoteDebian = ./PromoteDebian.dhall

let PromoteDocker = ./PromoteDocker.dhall

let PromoteDebianSpec = PromoteDebian.PromoteDebianSpec

let PromoteDockerSpec = PromoteDocker.PromoteDockerSpec

let Command = ../Base.dhall

let TaggedKey = Command.TaggedKey

let PromotePackagesSpec =
      { Type =
          { debians : List Package.Type
          , dockers : List Artifact.Type
          , version : Text
          , new_debian_version : Text
          , architecture : Text
          , profile : Profiles.Type
          , network : Network.Type
          , codenames : List DebianVersions.DebVersion
          , from_channel : DebianChannel.Type
          , to_channel : DebianChannel.Type
          , source_debian_repo : DebianRepo.Type
          , target_debian_repo : DebianRepo.Type
          , new_tags : List Text
          , remove_profile_from_name : Bool
          , publish : Bool
          , depends_on : List Command.TaggedKey.Type
          }
      , default =
          { debians = [] : List Package.Type
          , dockers = [] : List Artifact.Type
          , version = ""
          , new_debian_version = ""
          , source_debian_repo = DebianRepo.Type.Unstable
          , target_debian_repo = DebianRepo.Type.Nightly
          , architecture = "amd64"
          , profile = Profiles.Type.Standard
          , network = Network.Type.Mainnet
          , codenames = [] : List DebianVersions.DebVersion
          , from_channel = DebianChannel.Type.Unstable
          , to_channel = DebianChannel.Type.Compatible
          , new_tags = [] : List Text
          , remove_profile_from_name = False
          , depends_on = [] : List Command.TaggedKey.Type
          , publish = False
          }
      }

let promotePackagesToDebianSpecs
    : PromotePackagesSpec.Type -> List PromoteDebianSpec.Type
    =     \(promote_packages : PromotePackagesSpec.Type)
      ->  let debians_spec =
                List/map
                  Package.Type
                  (List PromoteDebianSpec.Type)
                  (     \(debian : Package.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDebianSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDebianSpec::{
                                , profile = promote_packages.profile
                                , package = debian
                                , version = promote_packages.version
                                , new_version =
                                    promote_packages.new_debian_version
                                , architecture = promote_packages.architecture
                                , network = promote_packages.network
                                , codename = codename
                                , from_channel = promote_packages.from_channel
                                , to_channel = promote_packages.to_channel
                                , source_repo =
                                    promote_packages.source_debian_repo
                                , target_repo =
                                    promote_packages.target_debian_repo
                                , remove_profile_from_name =
                                    promote_packages.remove_profile_from_name
                                , deps = promote_packages.depends_on
                                , step_key =
                                    "promote-debian-${Package.lowerName
                                                        debian}-${DebianVersions.lowerName
                                                                    codename}-to-${DebianChannel.lowerName
                                                                                     promote_packages.to_channel}"
                                }
                          )
                          promote_packages.codenames
                  )
                  promote_packages.debians

          in  Prelude.List.fold
                (List PromoteDebianSpec.Type)
                debians_spec
                (List PromoteDebianSpec.Type)
                (     \(a : List PromoteDebianSpec.Type)
                  ->  \(b : List PromoteDebianSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDebianSpec.Type)

let promotePackagesToDockerSpecs
    : PromotePackagesSpec.Type -> List PromoteDockerSpec.Type
    =     \(promote_artifacts : PromotePackagesSpec.Type)
      ->  let dockers_spec =
                List/map
                  Artifact.Type
                  (List PromoteDockerSpec.Type)
                  (     \(docker : Artifact.Type)
                    ->  List/map
                          DebianVersions.DebVersion
                          PromoteDockerSpec.Type
                          (     \(codename : DebianVersions.DebVersion)
                            ->  PromoteDockerSpec::{
                                , profile = promote_artifacts.profile
                                , name = docker
                                , version = promote_artifacts.version
                                , codename = codename
                                , new_tags = promote_artifacts.new_tags
                                , network = promote_artifacts.network
                                , publish = promote_artifacts.publish
                                , remove_profile_from_name =
                                    promote_artifacts.remove_profile_from_name
                                , deps = promote_artifacts.depends_on
                                , step_key =
                                    "add-tag-to-${Artifact.lowerName
                                                    docker}-${DebianVersions.lowerName
                                                                codename}-docker"
                                }
                          )
                          promote_artifacts.codenames
                  )
                  promote_artifacts.dockers

          in  Prelude.List.fold
                (List PromoteDockerSpec.Type)
                dockers_spec
                (List PromoteDockerSpec.Type)
                (     \(a : List PromoteDockerSpec.Type)
                  ->  \(b : List PromoteDockerSpec.Type)
                  ->  a # b
                )
                ([] : List PromoteDockerSpec.Type)

let promoteSteps
    :     List PromoteDebianSpec.Type
      ->  List PromoteDockerSpec.Type
      ->  Text
      ->  List TaggedKey.Type
      ->  List Command.Type
    =     \(debians_spec : List PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDockerSpec.Type)
      ->  \(step_name : Text)
      ->  \(initial_depends_on : List TaggedKey.Type)
      ->  let deps =
                  [ initial_depends_on ]
                # List/map
                    PromoteDebianSpec.Type
                    (List TaggedKey.Type)
                    (     \(spec : PromoteDebianSpec.Type)
                      ->  [ { name = step_name, key = spec.step_key } ]
                    )
                    debians_spec

          let indexed_debians_spec =
                Prelude.List.indexed PromoteDebianSpec.Type debians_spec

          let debians_spec =
                List/map
                  { index : Natural, value : PromoteDebianSpec.Type }
                  PromoteDebianSpec.Type
                  (     \ ( cons
                          : { index : Natural, value : PromoteDebianSpec.Type }
                          )
                    ->  let spec = cons.value

                        let deps =
                              Prelude.List.drop
                                cons.index
                                (List TaggedKey.Type)
                                deps

                        let dep = Prelude.List.head (List TaggedKey.Type) deps

                        in  PromoteDebianSpec::{
                            , deps =
                                Prelude.Optional.default
                                  (List TaggedKey.Type)
                                  ([] : List TaggedKey.Type)
                                  dep
                            , package = spec.package
                            , version = spec.version
                            , new_version = spec.new_version
                            , architecture = spec.architecture
                            , network = spec.network
                            , codename = spec.codename
                            , from_channel = spec.from_channel
                            , to_channel = spec.to_channel
                            , source_repo = spec.source_repo
                            , target_repo = spec.target_repo
                            , profile = spec.profile
                            , remove_profile_from_name =
                                spec.remove_profile_from_name
                            , step_key = spec.step_key
                            , if = spec.if
                            }
                  )
                  indexed_debians_spec

          in    List/map
                  PromoteDebianSpec.Type
                  Command.Type
                  (     \(spec : PromoteDebianSpec.Type)
                    ->  PromoteDebian.promoteDebianStep spec
                  )
                  debians_spec
              # List/map
                  PromoteDockerSpec.Type
                  Command.Type
                  (     \(spec : PromoteDockerSpec.Type)
                    ->  PromoteDocker.promoteDockerStep spec
                  )
                  dockers_spec

let promotePipeline
    :     List PromoteDebianSpec.Type
      ->  List PromoteDockerSpec.Type
      ->  DebianVersions.DebVersion
      ->  PipelineMode.Type
      ->  List TaggedKey.Type
      ->  Pipeline.Config.Type
    =     \(debians_spec : List PromoteDebianSpec.Type)
      ->  \(dockers_spec : List PromoteDockerSpec.Type)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  \(mode : PipelineMode.Type)
      ->  \(depends_on : List TaggedKey.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen = DebianVersions.dirtyWhen debVersion
            , path = "Release"
            , name = "PromotePackage"
            , tags = [] : List PipelineTag.Type
            , mode = mode
            }
          , steps =
              promoteSteps debians_spec dockers_spec "PromotePackage" depends_on
          }

in  { PromotePackagesSpec = PromotePackagesSpec
    , promotePackagesToDebianSpecs = promotePackagesToDebianSpecs
    , promotePackagesToDockerSpecs = promotePackagesToDockerSpecs
    , promoteSteps = promoteSteps
    , promotePipeline = promotePipeline
    }
