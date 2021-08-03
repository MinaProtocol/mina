let Prelude = ../../External/Prelude.dhall
let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern
let Pipeline = ../../Pipeline/Dsl.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Summon = ../../Command/Summon/Type.dhall
let Size = ../../Command/Size.dhall
let Libp2p = ../../Command/Libp2pHelperBuild.dhall
let ConnectToTestnet = ../../Command/ConnectToTestnet.dhall
let DockerImage = ../../Command/DockerImage.dhall

let dependsOnGitEnv = [ { name = "GitEnvUpload", key = "upload-git-env" } ]

let DebVersion = < Buster | Stretch >

let capitalName = \(debVersion : DebVersion) ->
  merge { Buster = "Buster", Stretch = "Stretch" } debVersion

let lowerName = \(debVersion : DebVersion) ->
  merge { Buster = "buster", Stretch = "stretch" } debVersion

let toolchainRunner = \(debVersion : DebVersion) ->
  merge { Buster = RunInToolchain.runInToolchainBuster, Stretch = RunInToolchain.runInToolchainStretch } debVersion

let dependsOn = \(debVersion : DebVersion) ->
  merge {
    Buster = [ dependsOnGitEnv # { name = "MinaArtifactBuster", key = "build-deb-pkg" }],
    Stretch = [ dependsOnGitEnv # { name = "MinaArtifactStretch", key = "build-deb-pkg" }]
  } debVersion