let Prelude = ../External/Prelude.dhall
let S = ../Lib/SelectFiles.dhall

let Cmd = ../Lib/Cmds.dhall

let Pipeline = ../Pipeline/Dsl.dhall
let Command = ../Command/Base.dhall
let Docker = ../Command/Docker/Type.dhall
let DockerLogin = ../Command/DockerLogin/Type.dhall
let Size = ../Command/Size.dhall
let JobSpec = ../Pipeline/JobSpec.dhall

in

Pipeline.build
  Pipeline.Config::{
      spec =
        JobSpec::{
            dirtyWhen = [
                S.strictlyStart (S.contains "buildkite/DOCKER_DEPLOY_ENV")
            ],
            name = "DockerArtifact"
        },
    steps = [
      Command.build
        Command.Config::{
          commands = [
            Cmd.run (
                "if [ ! -f DOCKER_DEPLOY_ENV ]; then" ++
                   "buildkite-agent artifact download --build $BUILDKITE_TRIGGERED_FROM_BUILD_ID DOCKER_DEPLOY_ENV .;" ++
                "fi"
            ),
            Cmd.run (
                "source DOCKER_DEPLOY_ENV && scripts/release-docker.sh" ++
                    " -s $CODA_SERVICE -v $CODA_GIT_TAG-$CODA_GIT_BRANCH-$CODA_GIT_HASH" ++
                    " --extra-args '--build-arg coda_version=$CODA_DEB_VERSION --build-arg deb_repo=$CODA_DEB_REPO'"
            )
          ],
          label = "Build and release Docker artifacts",
          key = "docker-artifact-release",
          target = Size.Large,
          docker_login = Some DockerLogin::{=}
        }
    ]
  }
