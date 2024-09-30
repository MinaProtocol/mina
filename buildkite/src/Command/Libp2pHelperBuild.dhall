let Command = ./Base.dhall

let Size = ./Size.dhall

let Toolchain = ../Constants/Toolchain.dhall

let BuildFlags = ../Constants/BuildFlags.dhall

let Cmd = ../Lib/Cmds.dhall

let DebianVersions = ../Constants/DebianVersions.dhall

let commands =
          \(debVersion : DebianVersions.DebVersion)
      ->  [ Cmd.run "chmod -R 777 src/app/libp2p_helper"
          , Cmd.run "chmod -R 777 src/libp2p_ipc"
          , Cmd.runInDocker
              Cmd.Docker::{
              , image = Toolchain.image debVersion
              , extraEnv = [ "GO=/usr/lib/go/bin/go" ]
              }
              "make libp2p_helper"
          , Cmd.run
              "cp src/app/libp2p_helper/result/bin/libp2p_helper . && buildkite/scripts/buildkite-artifact-helper.sh libp2p_helper"
          ]

let cmdConfig =
          \(debVersion : DebianVersions.DebVersion)
      ->  \(buildFlags : BuildFlags.Type)
      ->  Command.build
            Command.Config::{
            , commands = commands debVersion
            , label =
                "Build Libp2p helper for ${DebianVersions.capitalName
                                             debVersion} ${BuildFlags.toSuffixUppercase
                                                             buildFlags}"
            , key = "libp2p-helper${BuildFlags.toLabelSegment buildFlags}"
            , target = Size.Multi
            }

in  { step = cmdConfig }
