let Prelude = ../External/Prelude.dhall
let RunInToolchain = ../Command/RunInToolchain.dhall
let ContainerImages = ./ContainerImages.dhall

let DebVersion = < Buster | Stretch >

let capitalName = \(debVersion : DebVersion) ->
  merge { Buster = "Buster", Stretch = "Stretch" } debVersion

let lowerName = \(debVersion : DebVersion) ->
  merge { Buster = "buster", Stretch = "stretch" } debVersion

let toolchainRunner = \(debVersion : DebVersion) ->
  merge { Buster = RunInToolchain.runInToolchainBuster, Stretch = RunInToolchain.runInToolchainStretch } debVersion

let toolchainImage = \(debVersion : DebVersion) ->
  merge { Buster = ContainerImages.minaToolchainBuster, Stretch = ContainerImages.minaToolchainStretch } debVersion

in

{
  DebVersion = DebVersion,
  capitalName = capitalName,
  lowerName = lowerName,
  toolchainRunner = toolchainRunner,
  toolchainImage = toolchainImage
}
