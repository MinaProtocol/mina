let Selector = ../../src/Lib/SelectFiles.dhall
let JobSpec = ../../src/Pipeline/JobSpec.dhall
let Pipeline = ../../src/Pipeline/Dsl.dhall
let PipelineTag = ../../src/Pipeline/Tag.dhall
let Command = ../../src/Command/Base.dhall
let Docker = ../../src/Command/Docker/Type.dhall
let Size = ../../src/Command/Size.dhall
let Cmd = ../../src/Lib/Cmds.dhall

let config : Pipeline.Config.Type = Pipeline.Config::{
  spec = JobSpec::{
    dirtyWhen = [
        Selector.exactly "buildkite/test-drive/python/test" "py"
      ],
      path = "../../test-drive/dynamic",
      name = "Test", 
      tags = [ PipelineTag.Type.Test ]
  },
  steps = [
    Command.build Command.Config::{
      commands = [
        Cmd.run "python ./buildkite/test-drive/python/test.py"
      ],
      label = "Testing a dynamic pipeline",
      key = "test-drive",
      target = Size.Small,
      docker = Some Docker::{
        image = (../../src/Constants/ContainerImages.dhall).python,
        environment = ["BUILDKITE_AGENT_ACCESS_TOKEN"]
      }
    }
  ]
}

in (Pipeline.build config).pipeline