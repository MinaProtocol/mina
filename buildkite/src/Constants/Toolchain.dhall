let DebianVersions = ./DebianVersions.dhall

let RunInToolchain = ../Command/RunInToolchain.dhall

let ContainerImages = ./ContainerImages.dhall

let SelectionMode
    : Type
    = < ByDebian | Custom : Text >

let runner =
          \(debVersion : DebianVersions.DebVersion)
      ->  merge
            { Bookworm = RunInToolchain.runInToolchainBookworm
            , Bullseye = RunInToolchain.runInToolchainBullseye
            , Jammy = RunInToolchain.runInToolchainBookworm
            , Focal = RunInToolchain.runInToolchainBullseye
            }
            debVersion

let select =
          \(mode : SelectionMode)
      ->  \(debVersion : DebianVersions.DebVersion)
      ->  merge
            { ByDebian = runner debVersion
            , Custom =
                \(image : Text) -> RunInToolchain.runInToolchainImage image
            }
            mode

let image =
          \(debVersion : DebianVersions.DebVersion)
      ->  merge
            { Bookworm = ContainerImages.minaToolchainBookworm
            , Bullseye = ContainerImages.minaToolchainBullseye
            , Jammy = ContainerImages.minaToolchainBookworm
            , Focal = ContainerImages.minaToolchainBullseye
            }
            debVersion

in  { SelectionMode = SelectionMode
    , select = select
    , runner = runner
    , image = image
    }
