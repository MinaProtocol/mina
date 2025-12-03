let Cmd = ../Lib/Cmds.dhall

let Arch = ../Constants/Arch.dhall

let ContainerImages = ../Constants/ContainerImages.dhall

let fixPermissionsScript = "sudo chown -R opam ."

let command
    : Arch.Type -> Cmd.Type
    =     \(arch : Arch.Type)
      ->  let image =
                merge
                  { Amd64 = ContainerImages.minaToolchainBullseye.amd64
                  , Arm64 = ContainerImages.minaToolchainBullseye.arm64
                  }
                  arch

          in  Cmd.runInDocker Cmd.Docker::{ image = image } fixPermissionsScript

in  { command = command }
