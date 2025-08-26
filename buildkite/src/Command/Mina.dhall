let Cmd = ../Lib/Cmds.dhall

let Docker = ./Docker/Type.dhall

let Base = ./Base.dhall

let Size = ./Size.dhall

let dockerImage = (../Constants/ContainerImages.dhall).minaToolchain

let fixPermissionsScript = "sudo chown -R opam ."

let Config =
      { Type = { commands : List Cmd.Type, label : Text, key : Text }
      , default = {=}
      }

let build
    : Config.Type -> Base.Type
    =     \(c : Config.Type)
      ->  Base.build
            Base.Config::{
            , commands = [ Cmd.run fixPermissionsScript ] # c.commands
            , label = c.label
            , key = c.key
            , target = Size.Small
            , docker = Some Docker::{ image = dockerImage }
            }

in  { fixPermissionsCommand =
        Cmd.runInDocker Cmd.Docker::{ image = dockerImage } fixPermissionsScript
    , Config = Config
    , build = build
    , Type = Base.Type
    }
