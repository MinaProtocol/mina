let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "src/app/delegation_backend"),
          S.exactly "Makefile" "",
          S.exactly "buildkite/src/Jobs/Test/DelegationBackendUnitTest" "dhall"
        ],
        path = "Test",
        name = "DelegationBackendUnitTest"
      },
    steps = [
      Command.build
        Command.Config::{
          commands = [
            Cmd.runInDocker Cmd.Docker::{image = ContainerImages.delegationBackendToolchain} "cd src/app/delegation_backend && mkdir -p result && cp -R /headers result && cd src && go test"
          ],
          label = "delegation backend unit-tests",
          key = "delegation-backend-unit-tests",
          target = Size.Small,
          docker = None Docker.Type
        }
    ]
  }
