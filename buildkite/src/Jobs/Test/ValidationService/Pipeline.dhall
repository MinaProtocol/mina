let Pipeline = ../../../Pipeline/Dsl.dhall
let Command = ../../../Command/Base.dhall
let Docker = ../../../Command/Docker/Type.dhall
let Size = ../../../Command/Size.dhall
let ValidationService = ../../../Projects/ValidationService.dhall

in Pipeline.build Pipeline.Config::{
  spec = ./Spec.dhall,
  steps = [
    Command.build Command.Config::{
      commands = ValidationService.initCommands # [
        ValidationService.runMix "mix test"
      ],
      label = "Validation service tests; executes the ExUnit test suite",
      key = "test",
      target = Size.Small,
      docker = Some Docker::{ image = ValidationService.containerImage }
    }
  ]
}
