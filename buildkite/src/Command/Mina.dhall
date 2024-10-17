let Cmd = ../Lib/Cmds.dhall

let dockerImage = (../Constants/ContainerImages.dhall).minaToolchain

let fixPermissionsScript = "sudo chown -R opam ."

in  { fixPermissionsCommand =
        Cmd.runInDocker Cmd.Docker::{ image = dockerImage } fixPermissionsScript
    }
