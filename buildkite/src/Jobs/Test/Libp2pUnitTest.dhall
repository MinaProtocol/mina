let ContainerImages = ../../Constants/ContainerImages.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall

in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "src/app/libp2p_helper"),
          S.strictlyStart (S.contains "src/libp2p_ipc"),
          S.exactly "Makefile" "",
          S.exactly "buildkite/src/Jobs/Test/Libp2pUnitTest" "dhall"
        ],
        path = "Test",
        name = "Libp2pUnitTest"
      },
    steps = [
      Command.build
        Command.Config::{
          commands = [
            Cmd.run "chmod -R 777 src/libp2p_ipc",
            Cmd.runInDocker
              Cmd.Docker::
                { image=ContainerImages.minaToolchainBuster
                , extraEnv = [ "GO=/usr/lib/go/bin/go" ]
                } "make -C src/app/libp2p_helper test"
          ],
          label = "libp2p unit-tests",
          key = "libp2p-unit-tests",
          target = Size.Large,
          docker = None Docker.Type
        },
      Command.build
        Command.Config::{
          commands = [
            Cmd.run "chmod -R 777 src/libp2p_ipc",
            Cmd.runInDocker
              Cmd.Docker::
                { image=ContainerImages.minaToolchainBuster
                , extraEnv = [ "GO=/usr/lib/go/bin/go" ]
                } "make -C src/app/libp2p_helper test-bs-qc"
          ],
          label = "libp2p bitswap QuickCheck",
          key = "libp2p-bs-qc",
          target = Size.Large,
          docker = None Docker.Type,
          timeout_in_minutes = 45

        }
    ]
  }
