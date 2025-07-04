let Prelude = ../../External/Prelude.dhall

let Extensions = ../../Lib/Extensions.dhall

let join = Extensions.join

let Artifacts = ../../Constants/Artifacts.dhall

let Package = ../../Constants/DebianPackage.dhall

let Network = ../../Constants/Network.dhall

let Artifact = ../../Constants/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Spec =
      { Type =
          { artifacts : List Artifact.Type
          , networks : List Network.Type
          , version : Text
          , codenames : List DebianVersions.DebVersion
          , published_to_docker_io : Bool
          , suffix : Text
          }
      , default =
          { artifacts = [] : List Package.Type
          , networks = [ Network.Type.Mainnet, Network.Type.Devnet ]
          , codenames =
            [ DebianVersions.DebVersion.Focal
            , DebianVersions.DebVersion.Bullseye
            ]
          , published_to_docker_io = False
          , suffix = ""
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
      ->      ". ./buildkite/scripts/export-git-env-vars.sh && "
          ++  "./buildkite/scripts/release/manager.sh verify "
          ++  "--artifacts ${joinArtifacts spec} "
          ++  "--networks ${joinNetworks spec} "
          ++  "--version ${spec.version} "
          ++  "--codenames ${joinCodenames spec} "
          ++  "--docker-suffix '${spec.suffix}' "
          ++  "--only-dockers "

in  { verify = verify, Spec = Spec }
