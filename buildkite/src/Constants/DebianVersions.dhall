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
--- Same with Bullseye and Focal
let toolchainRunner = \(debVersion : DebVersion) ->
  merge {
    Bullseye = RunInToolchain.runInToolchainBullseye
    , Buster = RunInToolchain.runInToolchainBuster
    , Stretch = RunInToolchain.runInToolchainStretch
    , Focal = RunInToolchain.runInToolchainBullseye
    , Bionic = RunInToolchain.runInToolchainStretch
  } debVersion

--- Bionic and Stretch are so similar that they share a toolchain image
--- Same with Bullseye and Focal
let toolchainImage = \(debVersion : DebVersion) ->
  merge { 
    Bullseye = ContainerImages.minaToolchainBullseye
    , Buster = ContainerImages.minaToolchainBuster
    , Stretch = ContainerImages.minaToolchainStretch
    , Focal = ContainerImages.minaToolchainBullseye
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

-- Most debian builds are only used for public releases
-- so they don't need to be triggered by dirtyWhen on every change
-- these files representing changing the logic of the job, in which case test every platform
let minimalDirtyWhen = [
  S.strictlyStart (S.contains "buildkite/src/Command/MinaArtifact"),
  S.exactly "buildkite/scripts/build-artifact" "sh",
  S.strictlyStart (S.contains "buildkite/src/Constants"),
  S.strictlyStart (S.contains "buildkite/src/Command"),
  S.strictlyStart (S.contains "dockerfiles"),
  S.strictlyStart (S.contains "scripts")
]

-- The default debian version (Bullseye) is used in all downstream CI jobs
-- so the jobs must also trigger whenever src changes
let bullseyeDirtyWhen = [
  S.strictlyStart (S.contains "src"),
  S.strictlyStart (S.contains "automation"),
  S.strictly (S.contains "Makefile"),
  S.exactly "buildkite/scripts/connect-to-mainnet-on-compatible" "sh",
  S.strictlyStart (S.contains "buildkite/src/Jobs/Test")
] # dirtyWhen

in

let dirtyWhen = \(debVersion : DebVersion) ->
  merge {
    Bullseye = bullseyeDirtyWhen
    , Buster = minimalDirtyWhen
    , Stretch = minimalDirtyWhen
    , Bionic = minimalDirtyWhen
    , Focal = minimalDirtyWhen
  } debVersion

in

{
  DebVersion = DebVersion
  , capitalName = capitalName
  , lowerName = lowerName
  , toolchainRunner = toolchainRunner
  , toolchainImage = toolchainImage
  , dependsOn = dependsOn
  , dirtyWhen = dirtyWhen
}
