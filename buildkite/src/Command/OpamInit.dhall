let Prelude = ../External/Prelude.dhall

let Cmd = ../Lib/Cmds.dhall

let Coda = ../Command/Coda.dhall

let r = Cmd.run

let file =
  "\"opam-v3-\\\$(sha256sum opam_ci_cache.sig | cut -d\" \" -f1).tar.gz\""

-- Mv is faster than rm -rf
let unpackageScript : Text =
  "mv /home/opam/.opam /home/opam/.opam.bak && " ++
  "tar xfz ${file} --strip-components=2 && " ++
  "ln -s \\\$(pwd)/.opam /home/opam/.opam"

let commands : List Cmd.Type =
  [
    r ("cat scripts/setup-opam.sh src/opam.export <(date +%Y-%m)" ++
          "> opam_ci_cache.sig"),
    Cmd.cacheThrough
      Cmd.Docker::{
        image = (../Constants/ContainerImages.dhall).codaToolchain
      }
      file
      Cmd.CompoundCmd::{
        create = r "make setup-opam",
        package = r "tar cfz ${file} /home/opam/.opam"
      }
  ]

let andThenRunInDocker : Text -> List Cmd.Type =
  \(innerScript : Text) ->
    [ Coda.fixPermissionsCommand ] # commands # [
      Cmd.runInDocker
        (Cmd.Docker::{ image = (../Constants/ContainerImages.dhall).codaToolchain })
        (unpackageScript ++ " && " ++ innerScript)
    ]

in

{ andThenRunInDocker = andThenRunInDocker }

