let Prelude = ../External/Prelude.dhall
let Profiles = ./Profiles.dhall
let S = ../Lib/SelectFiles.dhall
let D = S.PathPattern

let DebVersion = < Bookworm | Bullseye | Buster | Jammy | Focal >

let capitalName = \(debVersion : DebVersion) ->
  merge {
    Bookworm = "Bookworm"
    , Bullseye = "Bullseye"
    , Buster = "Buster"
    , Jammy = "Jammy"
    , Focal = "Focal"
  } debVersion

let lowerName = \(debVersion : DebVersion) ->
  merge {
    Bookworm = "bookworm"
    , Bullseye = "bullseye"
    , Buster = "buster"
    , Jammy = "jammy"
    , Focal = "focal"
  } debVersion

let dependsOn = \(debVersion : DebVersion) -> \(profile : Profiles.Type) ->
  let profileSuffix = Profiles.toSuffixUppercase profile in
  let prefix = "MinaArtifact" in
  merge {
    Bookworm = [{ name = "${prefix}${profileSuffix}", key = "build-deb-pkg" }]
    , Bullseye = [{ name = "${prefix}${capitalName debVersion}${profileSuffix}", key = "build-deb-pkg" }]
    , Buster = [{ name = "${prefix}${capitalName debVersion}${profileSuffix}", key = "build-deb-pkg" }]
    , Jammy = [{ name = "${prefix}${capitalName debVersion}${profileSuffix}", key = "build-deb-pkg" }]
    , Focal = [{ name = "${prefix}${capitalName debVersion}${profileSuffix}", key = "build-deb-pkg" }]
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
  S.exactly "buildkite/scripts/build-artifact" "sh",
  -- Snark profiler dirtyWhen
  S.exactly "buildkite/src/Jobs/Test/RunSnarkProfiler" "dhall",
  S.exactly "buildkite/scripts/run-snark-transaction-profiler" "sh",
  S.exactly "scripts/snark_transaction_profiler" "py",
  S.exactly "buildkite/scripts/version-linter" "sh",
  S.exactly "scripts/version-linter" "py"
]

-- The default debian version (Bullseye) is used in all downstream CI jobs
-- so the jobs must also trigger whenever src changes
let bullseyeDirtyWhen = [
  S.strictlyStart (S.contains "src"),
  S.strictlyStart (S.contains "automation"),
  S.strictly (S.contains "Makefile"),
  S.exactly "buildkite/scripts/connect-to-berkeley" "sh",
  S.exactly "buildkite/scripts/connect-to-mainnet-on-compatible" "sh",
  S.exactly "buildkite/scripts/rosetta-integration-tests" "sh",
  S.exactly "buildkite/scripts/rosetta-integration-tests-full" "sh",
  S.exactly "buildkite/scripts/rosetta-integration-tests-fast" "sh",
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
  } debVersion

in

{
  DebVersion = DebVersion
  , capitalName = capitalName
  , lowerName = lowerName
  , dependsOn = dependsOn
  , dirtyWhen = dirtyWhen
}
