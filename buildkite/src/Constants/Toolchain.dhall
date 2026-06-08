let DebianVersions = ./DebianVersions.dhall

let RunInToolchain = ../Command/RunInToolchain.dhall

let Arch = ./Arch.dhall

let Cmd = ../Lib/Cmds.dhall

let SelectionMode
    : Type
    = < ByDebianAndArch | Custom : Text >

let Spec =
      { Type =
          { mode : SelectionMode
          , debVersion : DebianVersions.DebVersion
          , arch : Arch.Type
          , submodules : Bool
          }
      , default =
          { mode = SelectionMode.ByDebianAndArch
          , arch = Arch.Type.Amd64
          , submodules = False
          }
      }

let select
    : Spec.Type -> List Text -> Text -> List Cmd.Type
    =     \(spec : Spec.Type)
      ->  \(environment : List Text)
      ->  \(innerScript : Text)
      ->  let images = RunInToolchain.imageFor spec.arch

          let image =
                merge
                  { ByDebianAndArch =
                      merge
                        { Bookworm = images.bookworm
                        , Bullseye = images.bullseye
                        , Jammy = images.jammy
                        , Focal = images.focal
                        , Noble = images.noble
                        }
                        spec.debVersion
                  , Custom = \(image : Text) -> image
                  }
                  spec.mode

          in  RunInToolchain.runInToolchainImage
                RunInToolchain.Config::{
                , submodules = spec.submodules
                , image = image
                , arch = spec.arch
                , environment = environment
                , innerScript = innerScript
                }

in  { SelectionMode = SelectionMode, Spec = Spec, select = select }
