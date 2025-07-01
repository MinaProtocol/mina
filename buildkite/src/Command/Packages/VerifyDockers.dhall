let Prelude = ../../External/Prelude.dhall

let Extensions = ../../Lib/Extensions.dhall

let join = Extensions.join

let Artifacts = ../../Constants/Artifacts.dhall

let Size = ../../Command/Size.dhall

let Package = ../../Constants/DebianPackage.dhall

let Network = ../../Constants/Network.dhall

let Artifact = ../../Constants/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Command = ../Base.dhall

let Cmd = ../../Lib/Cmds.dhall

let Spec =
      { Type =
          { artifacts : List Artifact.Type
          , networks : List Network.Type
          , source_version : Text
          , codenames : List DebianVersions.DebVersion
          , published_to_docker_io : Bool
          , depends_on : List Command.TaggedKey.Type
          }
      , default =
          { artifacts = [] : List Package.Type
          , networks = [ Network.Type.Mainnet, Network.Type.Devnet ]
          , codenames =
            [ DebianVersions.DebVersion.Focal
            , DebianVersions.DebVersion.Bullseye
            ]
          , depends_on = [] : List Command.TaggedKey.Type
          , published_to_docker_io = False
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
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
              [ Cmd.run
                  (     ". ./buildkite/scripts/export-git-env-vars.sh && "
                    ++  "./buildkite/scripts/release/manager.sh verify "
                    ++  "--artifacts ${joinArtifacts spec} "
                    ++  "--networks ${joinNetworks spec} "
                    ++  "--version ${spec.source_version} "
                    ++  "--codenames ${joinCodenames spec} "
                    ++  "--only-dockers "
                  )
              ]
            , label = "Docker Packages Verification"
            , key = "verify-dockers"
            , target = Size.Small
            , depends_on = spec.depends_on
            }

in  { verify = verify, Spec = Spec }
