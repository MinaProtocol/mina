let Artifact = ../../Constants/Artifacts.dhall

let Prelude = ../../External/Prelude.dhall

let List/map = Prelude.List.map

let Command = ../Base.dhall

let Size = ../Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let PromoteDocker = ./PromoteDocker.dhall

let promoteDockerVerificationStep =
          \(spec : PromoteDocker.PromoteDockerSpec.Type)
      ->  let repo =
                      if spec.publish

                then  "docker.io/minaprotocol"

                else  "gcr.io/o1labs-192920"

          let commands =
                List/map
                  Text
                  Cmd.Type
                  (     \(tag : Text)
                    ->  let new_tag =
                              Artifact.dockerTag
                                spec.name
                                tag
                                spec.codename
                                spec.profile
                                spec.network
                                spec.remove_profile_from_name

                        in  Cmd.run
                              "docker pull ${repo}/${Artifact.dockerName
                                                       spec.name}:${new_tag}"
                  )
                  spec.new_tags

          in  Command.build
                Command.Config::{
                , commands = commands
                , label = "Docker: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.Small
                , depends_on = spec.deps
                , if = spec.if
                }

in  { promoteDockerVerificationStep = promoteDockerVerificationStep }
