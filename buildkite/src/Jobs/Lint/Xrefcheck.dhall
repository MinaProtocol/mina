let Prelude = ../../External/Prelude.dhall
let B = ../../External/Buildkite.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [
        SelectFiles.strictly (SelectFiles::{ exts = Some ["md"] }),
        SelectFiles.strictly (SelectFiles.contains ".xrefcheck.yml")
      ],
      path = "Lint",
      name = "Xrefcheck",
      tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Lint ]
    },
    steps = [
      Command.build
        Command.Config::{
          commands = [] : List Cmd.Type
          , label = "Verifies references in markdown"
          , key = "xrefcheck"
          , target = Size.Small
          , soft_fail = Some (B/SoftFail.Boolean True)
          , docker = Some Docker::{
              image = (../../Constants/ContainerImages.dhall).xrefcheck,
              shell = None (List Text)
            }
        }
    ]
  }
