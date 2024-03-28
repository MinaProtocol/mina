let DebianVersions = ./DebianVersions.dhall
let RunInToolchain = ../Command/RunInToolchain.dhall
let ContainerImages = ./ContainerImages.dhall

let SelectionMode: Type  = < ByDebian | Custom : Text >

--- Bullseye and Focal are so similar that they share a toolchain runner
--- Same with Bookworm and Jammy
let runner = \(debVersion : DebianVersions.DebVersion) ->
  merge {
     Bookworm = RunInToolchain.runInToolchainBookworm
     , Bullseye = RunInToolchain.runInToolchainBullseye
     , Buster = RunInToolchain.runInToolchainBuster
     , Jammy = RunInToolchain.runInToolchainBookworm
     , Focal = RunInToolchain.runInToolchainBullseye
   } debVersion

let select = \(mode: SelectionMode) -> \(debVersion : DebianVersions.DebVersion) ->
    merge {
        ByDebian = runner debVersion
        , Custom = \(image: Text) -> RunInToolchain.runInToolchainImage image
    } mode

--- Bullseye and Focal are so similar that they share a toolchain image
--- Same with Bookworm and Jammy
let image = \(debVersion : DebianVersions.DebVersion) ->
  merge { 
    Bookworm = ContainerImages.minaToolchainBookworm
    , Bullseye = ContainerImages.minaToolchainBullseye
    , Buster = ContainerImages.minaToolchainBuster
    , Jammy = ContainerImages.minaToolchainBookworm
    , Focal = ContainerImages.minaToolchainBullseye
  } debVersion

in

{
  SelectionMode = SelectionMode
  , select = select
  , runner = runner
  , image = image
}


