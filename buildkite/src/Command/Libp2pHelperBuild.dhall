let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall

let r = Cmd.run

let commands : List Cmd.Type =
  [
    let libp2p_dir = "src/app/libp2p_helper"
    let cache_dir = "${libp2p_dir}/result/bin"

    in

    Cmd.cacheThrough
      Cmd.Docker::{
        image = (../Constants/ContainerImages.dhall).codaToolchain,
        extraEnv = [ "LIBP2P_NIXLESS=1", "GO=/usr/lib/go/bin/go" ]
      }
      cache_dir
      Cmd.CompoundCmd::{
        preprocess = r "[ ! -d \"${libp2p_dir}\" ] && echo Libp2p helper \"directory ${libp2p_dir} DOES NOT exist.\" && exit 1",
        postprocess = r "[ ! -d \"${cache_dir}\" ] && echo helper build \"directory ${cache_dir} DOES NOT exist.\" && exit 1",
        inner = r "make libp2p_helper"
      }
  ]

in

{ commands = commands }
