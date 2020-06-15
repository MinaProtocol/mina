let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall

let r = Cmd.run

let commands : List Cmd.Type =
  [
    r "cat scripts/setup-opam.sh > opam_ci_cache.sig",
    r "cat src/opam.export >> opam_ci_cache.sig",
    r "date +%Y-%m >> opam_ci_cache.sig",
    let file =
      "opam-v2-`sha256sum opam_ci_cache.sig | cut -d\" \" -f1`.tar.gz"
    in
    Cmd.cacheThrough
      Cmd.Docker::{
        image = (../Constants/ContainerImages.dhall).codaToolchain
      }
      file
      Cmd.CompoundCmd::{
        preprocess = r "tar cfz ${file} /home/opam/.opam",
        postprocess = r "tar xfz ${file} -C /home/opam",
        inner = r "make setup-opam"
      }
  ]

in

{ commands = commands }

