let Prelude = ../External/Prelude.dhall

let Command = ./Base.dhall
let Size = ./Size.dhall

let Cmd = ../Lib/Cmds.dhall

in

let cmdConfig =
  Command.build
    Command.Config::{
      commands  = [
        Cmd.run "cp buildkite/scripts/export-git-env-vars.sh . && buildkite/scripts/buildkite-artifact-helper.sh export-git-env-vars.sh"
      ],
      label = "Upload deploy environment based on Git setup",
      key = "upload-git-env",
      target = Size.Small
    }

in

{ step = cmdConfig }
