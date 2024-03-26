let Prelude = ../External/Prelude.dhall
let Cmd = ../Lib/Cmds.dhall
let Mina = ../Command/Mina.dhall
let S = ../Lib/SelectFiles.dhall

let r = Cmd.run

let runInToolchainBookworm : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaToolchainBookworm, extraEnv = environment })
        (innerScript)
    ]

in

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

let runInToolchain : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaToolchain, extraEnv = environment })
        (innerScript)
    ]

in

{
  runInToolchain = runInToolchain
  , runInToolchainBookworm = runInToolchainBookworm
  , runInToolchainBullseye = runInToolchainBullseye
  , runInToolchainBuster = runInToolchainBuster
}
