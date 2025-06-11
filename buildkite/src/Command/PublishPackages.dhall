let Prelude = ../External/Prelude.dhall

let Optional/map = Prelude.Optional.map

let Optional/default = Prelude.Optional.default

let List/drop = Prelude.List.drop

let List/concatMap = Prelude.List.concatMap

let Text/concat = Prelude.Text.concat

let Artifacts = ../Constants/Artifacts.dhall

let Size = ../Command/Size.dhall

let Package = ../Constants/DebianPackage.dhall

let Network = ../Constants/Network.dhall

let DebianChannel = ../Constants/DebianChannel.dhall

let Profiles = ../Constants/Profiles.dhall

let Artifact = ../Constants/Artifacts.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let DebianRepo = ../Constants/DebianRepo.dhall

let Toolchain = ../Constants/Toolchain.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let Mina = ./Mina.dhall

let join =
          \(sep : Text)
      ->  \(xs : List Text)
      ->  let concatWithSepAtStart =
                List/concatMap Text Text (\(item : Text) -> [ sep, item ]) xs

          let concat = List/drop 1 Text concatWithSepAtStart

          in  Text/concat concat

let Spec =
      { Type =
          { artifacts : List Artifact.Type
          , networks : List Network.Type
          , backend : Text
          , channel : DebianChannel.Type
          , verify : Bool
          , source_version : Text
          , build_id : Text
          , target_version :
                  DebianVersions.DebVersion
              ->  DebianChannel.Type
              ->  Text
              ->  Profiles.Type
              ->  Text
              ->  Text
              ->  Text
              ->  Text
          , profile : Profiles.Type
          , codenames : List DebianVersions.DebVersion
          , debian_repo : DebianRepo.Type
          , new_docker_tags :
                  DebianVersions.DebVersion
              ->  DebianChannel.Type
              ->  Text
              ->  Profiles.Type
              ->  Text
              ->  Text
              ->  Text
              ->  List Text
          , publish_to_docker_io : Bool
          , depends_on : List Command.TaggedKey.Type
          , branch : Text
          }
      , default =
          { artifacts = [] : List Package.Type
          , debian_repo = DebianRepo.Type.Unstable
          , networks = [ Network.Type.Mainnet, Network.Type.Devnet ]
          , backend = "local"
          , codenames =
            [ DebianVersions.DebVersion.Focal
            , DebianVersions.DebVersion.Bullseye
            ]
          , channel = DebianChannel.Type.Compatible
          , depends_on = [] : List Command.TaggedKey.Type
          , publish_to_docker_io = False
          , verify = True
          , branch = ""
          }
      }

let publish
    : Spec.Type -> List Command.Type
    =     \(spec : Spec.Type)
      ->  let additional_tags =
                spec.new_docker_tags
                  DebianVersions.DebVersion.Bullseye
                  spec.channel
                  spec.branch
                  spec.profile
                  "\\\${GIT_COMMIT}"
                  "\\\${GITTAG}"
                  "\\\$(date \"+%Y%m%d\")"

          let target_version =
                spec.target_version
                  DebianVersions.DebVersion.Bullseye
                  spec.channel
                  spec.branch
                  spec.profile
                  "\\\${GIT_COMMIT}"
                  "\\\${GITTAG}"
                  "\\\$(date \"+%Y%m%d\")"

          let artifacts = join "," (Artifacts.dockerNames spec.artifacts)

          let networks =
                join
                  ","
                  ( Prelude.List.map
                      Network.Type
                      Text
                      (\(network : Network.Type) -> Network.lowerName network)
                      spec.networks
                  )

          let codenames =
                join
                  ","
                  ( Prelude.List.map
                      DebianVersions.DebVersion
                      Text
                      (     \(debian : DebianVersions.DebVersion)
                        ->  DebianVersions.lowerName debian
                      )
                      spec.codenames
                  )

          let maybeKey =
                Optional/map
                  Text
                  Text
                  (\(repo : Text) -> "--debian-sign-key " ++ repo)
                  (DebianRepo.keyId spec.debian_repo)

          let keyArg = Optional/default Text "" maybeKey

          let indexedAdditionalTags = Prelude.List.indexed Text additional_tags

          in    [ Command.build
                    Command.Config::{
                    , commands =
                          [ Mina.fixPermissionsCommand ]
                        # [ Cmd.runInDocker
                              Cmd.Docker::{
                              , image = ContainerImages.minaToolchain
                              , extraEnv =
                                [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                              , privileged = True
                              , useRoot = True
                              }
                              ( 
                                "git config --global --add safe.directory /workdir && "
                                ++  ". ./buildkite/scripts/export-git-env-vars.sh && "
                                ++  "whoami && "
                                ++  "./buildkite/scripts/release/manager.sh publish "
                                ++  "--artifacts ${artifacts} "
                                ++  "--networks ${networks} "
                                ++  "--buildkite-build-id ${spec.build_id} "
                                ++  "--backend ${spec.backend} "
                                ++  "--channel ${DebianChannel.lowerName
                                                   spec.channel} "
                                ++  "--verify "
                                ++  "--source-version ${spec.source_version} "
                                ++  "--target-version ${target_version} "
                                ++  "--codenames ${codenames} "
                                ++  "--debian-repo ${DebianRepo.bucket_or_default
                                                       spec.debian_repo} "
                                ++  "--only-debians "
                                ++  "${keyArg}"
                              )
                          ]
                    , label = "Debian Packages Publishing"
                    , key = "publish-debians"
                    , target = Size.Small
                    , depends_on = spec.depends_on
                    }
                ]
              # Prelude.List.map
                  { index : Natural, value : Text }
                  Command.Type
                  (     \(r : { index : Natural, value : Text })
                    ->  Command.build
                          Command.Config::{
                          , commands =
                              Toolchain.runner
                                DebianVersions.DebVersion.Bullseye
                                [ "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY" ]
                                (     ". ./buildkite/scripts/export-git-env-vars.sh && "
                                  ++  "./buildkite/scripts/release/manager.sh publish "
                                  ++  "--artifacts ${artifacts} "
                                  ++  "--networks ${networks} "
                                  ++  "--buildkite-build-id ${spec.build_id} "
                                  ++  "--backend ${spec.backend} "
                                  ++  "--channel ${DebianChannel.lowerName
                                                     spec.channel} "
                                  ++  "--verify "
                                  ++  "--source-version ${spec.source_version} "
                                  ++  "--target-version ${r.value} "
                                  ++  "--codenames ${codenames} "
                                  ++  "--only-dockers "
                                )
                          , label = "Docker Packages Publishing"
                          , key = "publish-dockers-${Natural/show r.index}"
                          , target = Size.Small
                          , depends_on = spec.depends_on
                          }
                  )
                  indexedAdditionalTags

in  { publish = publish, Spec = Spec }
