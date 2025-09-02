let Cmd = ../Lib/Cmds.dhall

let Mina = ../Command/Mina.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let Arch = ../Constants/Arch.dhall

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

let runInToolchainNoble
    : Arch.Type -> List Text -> Text -> List Cmd.Type
    =     \(arch : Arch.Type)
      ->  \(environment : List Text)
      ->  \(innerScript : Text)
      ->
        let image =
                merge
                  { Amd64 = ContainerImages.minaToolchainNoble.amd64
                  , Arm64 = ContainerImages.minaToolchainNoble.arm64
                  }
                  arch
        in  runInToolchainImage image environment innerScript

let runInToolchainJammy
    : List Text -> Text -> List Cmd.Type
    =     \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            ContainerImages.minaToolchainJammy
            environment
            innerScript

let runInToolchainBookworm
    : Arch.Type -> List Text -> Text -> List Cmd.Type
    =     \(arch : Arch.Type)
      ->  \(environment : List Text)
      ->  \(innerScript : Text)
      ->  let image =
                merge
                  { Amd64 = ContainerImages.minaToolchainBookworm.amd64
                  , Arm64 = ContainerImages.minaToolchainBookworm.arm64
                  }
                  arch

          in  runInToolchainImage image environment innerScript

let runInToolchainBullseye
    : Arch.Type -> List Text -> Text -> List Cmd.Type
    =     \(arch : Arch.Type)
      ->  \(environment : List Text)
      ->  \(innerScript : Text)
      ->  runInToolchainImage
            ContainerImages.minaToolchainBullseye.amd64
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
    , runInToolchainNoble = runInToolchainNoble
    , runInToolchainBookworm = runInToolchainBookworm
    , runInToolchainBullseye = runInToolchainBullseye
    , runInToolchainJammy = runInToolchainJammy
    }
