-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall

let commands : List Cmd.Type =
    [
        Cmd.run (
            "if [ ! -f DOCKER_DEPLOY_ENV ]; then " ++
                "buildkite-agent artifact download DOCKER_DEPLOY_ENV .; " ++
            "fi"
        ),
        Cmd.run "./buildkite/scripts/docker-artifact.sh"
    ]

in

let generateStep = \(deps : List Command.TaggedKey.Type) ->
    Command.build
      Command.Config::{
        commands  = commands,
        label = "Build and release Docker artifacts",
        key = "docker-artifact",
        target = Size.Medium,
        docker_login = Some DockerLogin::{=},
        depends_on = deps
      }

in

{ generateStep = generateStep }
