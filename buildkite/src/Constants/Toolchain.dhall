let DebianVersions = ./DebianVersions.dhall

let ContainerImages = ./ContainerImages.dhall

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

let imageFor
    : DebianVersions.DebVersion -> Arch.Type -> Text
    =     \(debVersion : DebianVersions.DebVersion)
      ->  \(arch : Arch.Type)
      ->  merge
            { Bookworm =
                merge
                  { Amd64 = ContainerImages.minaToolchainBookworm.amd64
                  , Arm64 = ContainerImages.minaToolchainBookworm.arm64
                  }
                  arch
            , Bullseye = ContainerImages.minaToolchainBullseye.amd64
            , Jammy = ContainerImages.minaToolchainJammy.amd64
            , Focal = ContainerImages.minaToolchain
            , Noble = ContainerImages.minaToolchainNoble.amd64
            }
            debVersion

let select
    : Spec.Type -> List Text -> Text -> List Cmd.Type
    =     \(spec : Spec.Type)
      ->  \(environment : List Text)
      ->  \(innerScript : Text)
      ->  let image =
                merge
                  { ByDebianAndArch = imageFor spec.debVersion spec.arch
                  , Custom = \(image : Text) -> image
                  }
                  spec.mode

          in  RunInToolchain.runInToolchain
                RunInToolchain.Config::{
                , submodules = spec.submodules
                , image = image
                , arch = spec.arch
                , environment = environment
                , innerScript = innerScript
                }

in  { SelectionMode = SelectionMode, Spec = Spec, select = select }
