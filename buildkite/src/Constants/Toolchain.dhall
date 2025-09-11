let DebianVersions = ./DebianVersions.dhall

let RunInToolchain = ../Command/RunInToolchain.dhall

let Arch = ./Arch.dhall

let SelectionMode
    : Type
    = < ByDebianAndArch | Custom : Text >

let runner =
          \(debVersion : DebianVersions.DebVersion)
      ->  \(arch : Arch.Type)
      ->  merge
            { Bookworm = RunInToolchain.runInToolchainBookworm arch
            , Bullseye = RunInToolchain.runInToolchain
            , Jammy = RunInToolchain.runInToolchainJammy
            , Focal = RunInToolchain.runInToolchain
            , Noble = RunInToolchain.runInToolchainNoble arch
            }
            debVersion

let select =
          \(mode : SelectionMode)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  \(arch : Arch.Type)
      ->  merge
            { ByDebianAndArch = runner debVersion arch
            , Custom =
                \(image : Text) -> RunInToolchain.runInToolchainImage image
            }
            mode

in  { SelectionMode = SelectionMode, select = select, runner = runner }
