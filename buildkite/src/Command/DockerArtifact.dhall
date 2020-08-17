-- Execute Docker artifact release script according to build scoped DOCKER_DEPLOY_ENV

let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

let DockerLogin = ../Command/DockerLogin/Type.dhall


let defaultArtifactStep = { name = "Artifact", key = "build-artifact" }

let generateStep = \(deps : List Command.TaggedKey.Type) ->
    -- assume head or first dependency specified represents the primary artifact dependency step
    let artifactUploadScope = List/head Command.TaggedKey.Type deps
    let scopeName = "${(Prelude.Optional.default Command.TaggedKey.Type defaultArtifactStep artifactUploadScope).name}"
    let scopeKey = "${(Prelude.Optional.default Command.TaggedKey.Type defaultArtifactStep artifactUploadScope).key}"

    let commands : List Cmd.Type =
    [
        Cmd.run (
            "if [ ! -f DOCKER_DEPLOY_ENV ]; then " ++
                "buildkite-agent artifact download --step _${scopeName}-${scopeKey} DOCKER_DEPLOY_ENV .; " ++
            "fi"
        ),
        Cmd.run "./buildkite/scripts/docker-artifact.sh"
    ]

    in

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
