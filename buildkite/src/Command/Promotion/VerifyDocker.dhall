let Artifact = ../../Constants/Artifacts.dhall

let Command = ../Base.dhall

let Size = ../Size.dhall

let Cmd = ../../Lib/Cmds.dhall

let PromoteDocker = ./PromoteDocker.dhall

let promoteDockerVerificationStep =
          \(spec : PromoteDocker.PromoteDockerSpec.Type)
      ->  let new_tag =
                Artifact.dockerTag
                  spec.name
                  spec.new_tag
                  spec.codename
                  spec.profile
                  spec.network
                  spec.remove_profile_from_name

          let repo =
                      if spec.publish

                then  "docker.io/minaprotocol"

                else  "gcr.io/o1labs-192920"

          in  Command.build
                Command.Config::{
                , commands =
                  [ Cmd.run
                      "docker pull ${repo}/${Artifact.dockerName
                                               spec.name}:${new_tag}"
                  ]
                , label = "Docker: ${spec.step_key}"
                , key = spec.step_key
                , target = Size.Small
                , depends_on = spec.deps
                , if = spec.if
                }

in  { promoteDockerVerificationStep = promoteDockerVerificationStep }
