
let S = ../../Lib/SelectFiles.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let ValidationService = ../../Projects/ValidationService.dhall

in Pipeline.build Pipeline.Config::{
  spec =
    let dirtyDhallDir = S.strictlyStart (S.contains "buildkite/src/Jobs/Test/ValidationService")
    in JobSpec::{
    dirtyWhen = [
      dirtyDhallDir,
      S.strictlyStart (S.contains ValidationService.rootPath)
    ],
    path = "Test",
    name = "ValidationService"
  },
  steps = [
    Command.build Command.Config::{
      commands = ValidationService.initCommands # [
        ValidationService.runMix "test"
      ],
      label = "Validation service tests; executes the ExUnit test suite",
      key = "test",
      target = Size.Small,
      docker = Some Docker::{ image = ValidationService.containerImage }
    }
  ]
}
