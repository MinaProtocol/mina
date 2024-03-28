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

let runInToolchainCaqtiBookworm : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaCaqtiToolchainBookworm, extraEnv = environment })
        (innerScript)
    ]

in

let runInToolchainCaqtiBullseye : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaCaqtiToolchainBullseye, extraEnv = environment })
        (innerScript)
    ]

in

let runInToolchainCaqtiBuster : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaCaqtiToolchainBuster, extraEnv = environment })
        (innerScript)
    ]

let runInToolchainCaqti : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).minaCaqtiToolchain, extraEnv = environment })
        (innerScript)
    ]

in
{
  runInToolchain = runInToolchain
  , runInToolchainBookworm = runInToolchainBookworm
  , runInToolchainBullseye = runInToolchainBullseye
  , runInToolchainBuster = runInToolchainBuster
  , runInToolchainCaqti = runInToolchainCaqti
  , runInToolchainCaqtiBookworm = runInToolchainCaqtiBookworm
  , runInToolchainCaqtiBullseye = runInToolchainCaqtiBullseye
  , runInToolchainCaqtiBuster = runInToolchainCaqtiBuster
}
