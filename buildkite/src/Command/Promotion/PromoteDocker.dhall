let B = ../../External/Buildkite.dhall

let B/If = B.definitions/commandStep/properties/if/Type

let Network = ../../Constants/Network.dhall

let Profiles = ../../Constants/Profiles.dhall

let Artifact = ../../Constants/Artifacts.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Command = ../Base.dhall

let Size = ../Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let PromoteDockerSpec =
      { Type =
          { deps : List Command.TaggedKey.Type
          , name : Artifact.Type
          , version : Text
          , profile : Profiles.Type
          , codename : DebianVersions.DebVersion
          , new_tag : Text
          , network : Network.Type
          , step_key : Text
          , if : Optional B/If
          , publish : Bool
          , remove_profile_from_name : Bool
          }
      , default =
          { deps = [] : List Command.TaggedKey.Type
          , name = Artifact.Type.Daemon
          , version = ""
          , new_tag = ""
          , step_key = "promote-docker"
          , profile = Profiles.Type.Standard
          , network = Network.Type.Berkeley
          , codename = DebianVersions.DebVersion.Bullseye
          , if = None B/If
          , publish = False
          , remove_profile_from_name = False
          }
      }

let promoteDockerStep =
          \(spec : PromoteDockerSpec.Type)
      ->  let old_tag =
                Artifact.dockerTag
                  spec.name
                  spec.version
                  spec.codename
                  spec.profile
                  spec.network
                  False

          let new_tag =
                Artifact.dockerTag
                  spec.name
                  spec.new_tag
                  spec.codename
                  spec.profile
                  spec.network
                  spec.remove_profile_from_name

          let publish = if spec.publish then "-p" else ""

          in  Command.build
                Command.Config::{
                , commands =
                  [ Cmd.run
                      ". ./buildkite/scripts/export-git-env-vars.sh && ./buildkite/scripts/promote-docker.sh --name ${Artifact.dockerName
                                                                        spec.name} --version ${old_tag} --tag ${new_tag} ${publish}"
                  ]
                , label = "Docker: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.XLarge
                , depends_on = spec.deps
                , if = spec.if
                }

in  { PromoteDockerSpec = PromoteDockerSpec
    , promoteDockerStep = promoteDockerStep
    }
