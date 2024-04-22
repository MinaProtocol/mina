let Prelude = ../External/Prelude.dhall
let Cmd = ../Lib/Cmds.dhall
let Mina = ../Command/Mina.dhall
let S = ../Lib/SelectFiles.dhall
let ContainerImages = ../Constants/ContainerImages.dhall

let r = Cmd.run

let runInToolchainImage : Text -> List Text  -> Text ->  List Cmd.Type =
  \(image: Text) ->
  \(environment : List Text) ->
  \(innerScript : Text) ->
    [ Mina.fixPermissionsCommand ] # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = image, extraEnv = environment })
        (innerScript)
    ]

in

let runInToolchainBookworm : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    runInToolchainImage ContainerImages.minaToolchainBookworm environment innerScript

in

let runInToolchainBullseye : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    runInToolchainImage ContainerImages.minaToolchainBullseye environment innerScript 

in

let runInToolchainBuster : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    runInToolchainImage ContainerImages.minaToolchainBuster environment innerScript 


let runInToolchain : List Text -> Text -> List Cmd.Type =
  \(environment : List Text) ->
  \(innerScript : Text) ->
    runInToolchainImage ContainerImages.minaToolchain environment innerScript 


in

{
  runInToolchain = runInToolchain
  , runInToolchainImage  = runInToolchainImage
  , runInToolchainBookworm = runInToolchainBookworm
  , runInToolchainBullseye = runInToolchainBullseye
  , runInToolchainBuster = runInToolchainBuster
}
