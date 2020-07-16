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
        Cmd.run (
            "source DOCKER_DEPLOY_ENV; scripts/release-docker.sh" ++
                " -s $CODA_SERVICE -v $CODA_VERSION" ++
                " --extra-args '--build-arg coda_version=$CODA_VERSION --build-arg deb_repo=$CODA_DEB_REPO'"
        )
    ]

in

let cmdConfig =
  Command.build
    Command.Config::{
      commands  = commands,
      label = "Docker artifact build/release commands",
      key = "docker-artifact",
      target = Size.Large,
      docker_login = Some DockerLogin::{=},
      depends_on = [ { name = "artifact-upload", key = "_artifact-upload" } ]
    }

in

{ step = cmdConfig }
