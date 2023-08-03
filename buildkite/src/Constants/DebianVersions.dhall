let Prelude = ../External/Prelude.dhall
let RunInToolchain = ../Command/RunInToolchain.dhall
let ContainerImages = ./ContainerImages.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let DebVersion = < Bookworm | Bullseye | Buster | Jammy | Focal | Bionic >

let capitalName = \(debVersion : DebVersion) ->
  merge {
    Bookworm = "Bookworm"
    , Bullseye = "Bullseye"
    , Buster = "Buster"
    , Jammy = "Jammy"
    , Focal = "Focal"
    , Bionic = "Bionic"
  } debVersion

let lowerName = \(debVersion : DebVersion) ->
  merge {
    Bookworm = "bookworm"
    , Bullseye = "bullseye"
    , Buster = "buster"
    , Jammy = "jammy"
    , Focal = "focal"
    , Bionic = "bionic"
  } debVersion

--- Bionic and Stretch are so similar that they share a toolchain runner
--- Same with Bullseye and Focal
--- Same with Bookworm and Jammy
let toolchainRunner = \(debVersion : DebVersion) ->
  merge {
    Bookworm = RunInToolchain.runInToolchainBookworm
    , Bullseye = RunInToolchain.runInToolchainBullseye
    , Buster = RunInToolchain.runInToolchainBuster
    , Jammy = RunInToolchain.runInToolchainBookworm
    , Focal = RunInToolchain.runInToolchainBullseye
    , Bionic = RunInToolchain.runInToolchainBionic
  } debVersion

--- Bionic and Stretch are so similar that they share a toolchain image
--- Same with Bullseye and Focal
--- Same with Bookworm and Jammy
let toolchainImage = \(debVersion : DebVersion) ->
  merge { 
    Bookworm = ContainerImages.minaToolchainBookworm
    , Bullseye = ContainerImages.minaToolchainBullseye
    , Buster = ContainerImages.minaToolchainBuster
    , Jammy = ContainerImages.minaToolchainBookworm
    , Focal = ContainerImages.minaToolchainBullseye
    , Bionic = ContainerImages.minaToolchainBionic
  } debVersion

let dependsOn = \(debVersion : DebVersion) ->
  merge {
    Bookworm = [{ name = "MinaArtifactBookworm", key = "build-deb-pkg" }]
    , Bullseye = [{ name = "MinaArtifactBullseye", key = "build-deb-pkg" }]
    , Buster = [{ name = "MinaArtifactBuster", key = "build-deb-pkg" }]
    , Jammy = [{ name = "MinaArtifactJammy", key = "build-deb-pkg" }]
    , Focal = [{ name = "MinaArtifactFocal", key = "build-deb-pkg" }]
    , Bionic = [{ name = "MinaArtifactBionic", key = "build-deb-pkg" }]
  } debVersion

-- Most debian builds are only used for public releases
-- so they don't need to be triggered by dirtyWhen on every change
-- these files representing changing the logic of the job, in which case test every platform
let minimalDirtyWhen = [
  S.exactly "buildkite/src/Constants/DebianVersions" "dhall",
  S.exactly "buildkite/src/Constants/ContainerImages" "dhall",
  S.exactly "buildkite/src/Command/MinaArtifact" "sh",
  S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaArtifact"),
  S.strictlyStart (S.contains "dockerfiles/stages"),
  S.exactly "scripts/rebuild-deb" "sh",
  S.exactly "scripts/release-docker" "sh",
  S.exactly "buildkite/scripts/build-artifact" "sh"
]

-- The default debian version (Bullseye) is used in all downstream CI jobs
-- so the jobs must also trigger whenever src changes
let bullseyeDirtyWhen = [
  S.strictlyStart (S.contains "src"),
  S.strictlyStart (S.contains "automation"),
  S.strictly (S.contains "Makefile"),
  S.exactly "buildkite/scripts/connect-to-mainnet-on-compatible" "sh",
  S.strictlyStart (S.contains "buildkite/src/Jobs/Test")
] # minimalDirtyWhen

in

let dirtyWhen = \(debVersion : DebVersion) ->
  merge {
    Bookworm = minimalDirtyWhen
    , Bullseye = bullseyeDirtyWhen
    , Buster = minimalDirtyWhen
    , Jammy = minimalDirtyWhen
    , Focal = minimalDirtyWhen
    , Bionic = minimalDirtyWhen
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
