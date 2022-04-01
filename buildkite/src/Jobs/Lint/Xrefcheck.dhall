let Prelude = ../../External/Prelude.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Cmd = ../../Lib/Cmds.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec = JobSpec::{
      dirtyWhen = [
        SelectFiles.strictly (SelectFiles::{ exts = Some ["md"] }),
        SelectFiles.strictly (SelectFiles.contains ".xrefcheck.yml")
      ],
      path = "Lint",
      name = "Xrefcheck"
    },
    steps = [
      Command.build
        Command.Config::{
          commands = [] : List Cmd.Type
          , label = "Verifies references in markdown"
          , key = "xrefcheck"
          , target = Size.Small
          , docker = Some Docker::{
              image = (../../Constants/ContainerImages.dhall).xrefcheck,
              shell = None (List Text)
            }
        }
    ]
  }
