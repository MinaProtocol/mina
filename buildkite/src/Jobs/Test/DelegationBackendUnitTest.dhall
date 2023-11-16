let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let B = ../../External/Buildkite.dhall
let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

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
        name = "DelegationBackendUnitTest",
        tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
      },
    steps = [
      Command.build
        Command.Config::{
          commands = [
            Cmd.runInDocker Cmd.Docker::{image = ContainerImages.delegationBackendToolchain} "cd src/app/delegation_backend && mkdir -p result && cp -R /headers result && cd src/delegation_backend && go test"
          ],
          label = "delegation backend unit-tests",
          soft_fail = Some (B/SoftFail.Boolean True),
          key = "delegation-backend-unit-tests",
          target = Size.Small,
          docker = None Docker.Type
        }
    ]
  }
