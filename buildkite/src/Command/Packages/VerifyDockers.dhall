let Prelude = ../../External/Prelude.dhall

let Extensions = ../../Lib/Extensions.dhall

let join = Extensions.join

let Artifacts = ../../Constants/Artifacts.dhall

let Package = ../../Constants/DebianPackage.dhall

let Network = ../../Constants/Network.dhall

let Artifact = ../../Constants/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Arch = ../../Constants/Arch.dhall

let Spec =
      { Type =
          { artifacts : List Artifact.Type
          , networks : List Network.Type
          , version : Text
          , codenames : List DebianVersions.DebVersion
          , published_to_docker_io : Bool
          , suffix : Optional Text
          , arch : Arch.Type
          }
      , default =
          { artifacts = [] : List Package.Type
          , networks = [ Network.Type.Mainnet, Network.Type.Devnet ]
          , codenames =
            [ DebianVersions.DebVersion.Focal
            , DebianVersions.DebVersion.Bullseye
            ]
          , published_to_docker_io = False
          , suffix = None Text
          , arch = Arch.Type.Amd64
          }
      }

let joinArtifacts
    : Spec.Type -> Text
    = \(spec : Spec.Type) -> join "," (Artifacts.dockerNames spec.artifacts)

let joinNetworks
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->  join
            ","
            ( Prelude.List.map
                Network.Type
                Text
                (\(network : Network.Type) -> Network.lowerName network)
                spec.networks
            )

let joinCodenames
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->  join
            ","
            ( Prelude.List.map
                DebianVersions.DebVersion
                Text
                (     \(debian : DebianVersions.DebVersion)
                  ->  DebianVersions.lowerName debian
                )
                spec.codenames
            )

let verify
    : Spec.Type -> Text
    =     \(spec : Spec.Type)
      ->  let arch = Arch.toOptional spec.arch

          let suffixAndArchFlag =
                let archFlag =
                      Prelude.Optional.map
                        Text
                        Text
                        (\(archValue : Text) -> "--arch ${archValue} ")
                        arch

                let suffixFlag =
                      Prelude.Optional.map
                        Text
                        Text
                        (\(suffix : Text) -> "--docker-suffix ${suffix} ")
                        spec.suffix

                in      Prelude.Optional.default Text "" archFlag
                    ++  Prelude.Optional.default Text "" suffixFlag

          in      ". ./buildkite/scripts/export-git-env-vars.sh && "
              ++  "./buildkite/scripts/release/manager.sh verify "
              ++  suffixAndArchFlag
              ++  "--artifacts ${joinArtifacts spec} "
              ++  "--networks ${joinNetworks spec} "
              ++  "--version ${spec.version} "
              ++  "--codenames ${joinCodenames spec} "
              ++  merge
                    { None = ""
                    , Some = \(suffix : Text) -> "--docker-suffix ${suffix} "
                    }
                    spec.suffix
              ++  "--only-dockers "

in  { verify = verify, Spec = Spec }
