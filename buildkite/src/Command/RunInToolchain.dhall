let Cmd = ../Lib/Cmds.dhall

let Mina = ../Command/Mina.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let runInToolchainImage
    : Text -> List Text -> Text -> List Cmd.Type
    =     \(image : Text)
      ->  \(environment : List Text)
      ->  \(innerScript : Text)
      ->    [ Mina.fixPermissionsCommand ]
          # [ Cmd.runInDocker
                Cmd.Docker::{ image = image, extraEnv = environment }
                innerScript
            ]

let runInToolchainBookworm
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            ContainerImages.minaToolchainBookworm
            environment
            innerScript

let runInToolchainBullseye
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            ContainerImages.minaToolchainBullseye
            environment
            innerScript

let runInToolchain
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            ContainerImages.minaToolchain
            environment
            innerScript

in  { runInToolchain = runInToolchain
    , runInToolchainImage = runInToolchainImage
    , runInToolchainBookworm = runInToolchainBookworm
    , runInToolchainBullseye = runInToolchainBullseye
    }
