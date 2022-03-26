let Prelude = ../External/Prelude.dhall
let RunInToolchain = ../Command/RunInToolchain.dhall
let ContainerImages = ./ContainerImages.dhall

let DebVersion = < Bullseye | Buster | Stretch | Focal | Bionic >

let capitalName = \(debVersion : DebVersion) ->
  merge {
    Bullseye = "Bullseye"
    , Buster = "Buster"
    , Stretch = "Stretch"
    , Focal = "Focal"
    , Bionic = "Bionic"
  } debVersion

let lowerName = \(debVersion : DebVersion) ->
  merge {
    Bullseye = "bullseye"
    , Buster = "buster"
    , Stretch = "stretch"
    , Focal = "focal"
    , Bionic = "bionic"
  } debVersion

--- Bionic and Stretch are so similar that they share a toolchain image
let toolchainRunner = \(debVersion : DebVersion) ->
  merge {
    Bullseye = RunInToolchain.runInToolchainBullseye
    , Buster = RunInToolchain.runInToolchainBuster
    , Stretch = RunInToolchain.runInToolchainStretch
    , Focal = RunInToolchain.runInToolchainFocal
    , Bionic = RunInToolchain.runInToolchainStretch
  } debVersion

--- Bionic and Stretch are so similar that they share a toolchain image
let toolchainImage = \(debVersion : DebVersion) ->
  merge { 
    Bullseye = ContainerImages.minaToolchainBullseye
    , Buster = ContainerImages.minaToolchainBuster
    , Stretch = ContainerImages.minaToolchainStretch
    , Focal = ContainerImages.minaToolchainFocal
    , Bionic = ContainerImages.minaToolchainStretch
  } debVersion

let dependsOn = \(debVersion : DebVersion) ->
  merge {
    Bullseye = [{ name = "MinaArtifactBullseye", key = "build-deb-pkg" }]
    , Buster = [{ name = "MinaArtifactBuster", key = "build-deb-pkg" }]
    , Stretch = [{ name = "MinaArtifactStretch", key = "build-deb-pkg" }]
    , Bionic = [{ name = "MinaArtifactBionic", key = "build-deb-pkg" }]
    , Focal = [{ name = "MinaArtifactFocal", key = "build-deb-pkg" }]
  } debVersion

in

{
  DebVersion = DebVersion
  , capitalName = capitalName
  , lowerName = lowerName
  , toolchainRunner = toolchainRunner
  , toolchainImage = toolchainImage
  , dependsOn = dependsOn
}
