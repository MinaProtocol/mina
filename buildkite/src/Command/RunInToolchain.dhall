let Prelude = ../External/Prelude.dhall
let Cmd = ../Lib/Cmds.dhall
let Mina = ../Command/Mina.dhall
let S = ../Lib/SelectFiles.dhall

let r = Cmd.run

let runInToolchainBullseye : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaToolchainBullseye, extraEnv = environment })
        (innerScript)
    ]

in

let runInToolchainBuster : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaToolchainBuster, extraEnv = environment })
        (innerScript)
    ]

let runInToolchainStretch : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaToolchainStretch, extraEnv = environment })
        (innerScript)
    ]

in

let runInToolchainFocal : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaToolchainFocal, extraEnv = environment })
        (innerScript)
    ]

in

{
  runInToolchainBullseye = runInToolchainBullseye
  , runInToolchainBuster = runInToolchainBuster
  , runInToolchainStretch = runInToolchainStretch
  , runInToolchainFocal = runInToolchainFocal
}
