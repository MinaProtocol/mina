let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall

let r = Cmd.run

let commands : List Cmd.Type =
  [
    r ("cat scripts/setup-opam.sh src/opam.export <(date +%Y-%m)" ++
          "> opam_ci_cache.sig"),
    let file =
      "\"opam-v2-\\\$(sha256sum opam_ci_cache.sig | cut -d\" \" -f1).tar.gz\""
    in
    Cmd.cacheThrough
      Cmd.Docker::{
        image = (../Constants/ContainerImages.dhall).codaToolchain
      }
      file
      Cmd.CompoundCmd::{
        unpackage = Some (r "tar xfz ${file} -C /home/opam"),
        create = r "make setup-opam",
        package = r "tar cfz ${file} /home/opam/.opam"
      }
  ]

in

{ commands = commands }

