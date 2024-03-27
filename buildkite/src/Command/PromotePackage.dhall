let B = ../External/Buildkite.dhall
let B/If = B.definitions/commandStep/properties/if/Type

let Prelude = ../External/Prelude.dhall
let Optional/toList = Prelude.Optional.toList
let Optional/map = Prelude.Optional.map
let List/map = Prelude.List.map
let Package = ../Constants/DebianPackage.dhall
let PipelineMode = ../Pipeline/Mode.dhall
let PipelineTag = ../Pipeline/Tag.dhall
let Pipeline = ../Pipeline/Dsl.dhall
let JobSpec = ../Pipeline/JobSpec.dhall
let DebianChannel = ../Constants/DebianChannel.dhall
let Profiles = ../Constants/Profiles.dhall
let Artifact = ../Constants/Artifacts.dhall
let DebianVersions = ../Constants/DebianVersions.dhall
let Command = ./Base.dhall
let Docker = ./Docker/Type.dhall
let Size = ./Size.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Cmd = ../Lib/Cmds.dhall

let PromoteDebianSpec = {
  Type = {
    deps: List Command.TaggedKey.Type,
    package: Package.Type,
    version: Text,
    new_version: Text,
    architecture: Text,
    codename: DebianVersions.DebVersion,
    from_channel: DebianChannel.Type,
    to_channel: DebianChannel.Type,
    profile: Profiles.Type,
    step_key: Text,
    `if`: Optional B/If
  },
  default = {
    deps = [] : List Command.TaggedKey.Type,
    package = Package.Type.LogProc,
    version = "",
    new_version = "",
    architecture = "amd64",
    codename = DebianVersions.DebVersion.Bullseye,
    from_channel = DebianChannel.Type.Unstable,
    to_channel = DebianChannel.Type.Nightly,
    profile = Profiles.Type.Standard,
    step_key = "promote-debian-package",
    `if` = None B/If
  }
}

let PromoteDockerSpec = {
  Type = {
    deps: List Command.TaggedKey.Type,
    name: Artifact.Type,
    version: Text,
    profile: Profiles.Type,
    new_tag: Text,
    step_key: Text,
    `if`: Optional B/If
  },
  default = {
    deps = [] : List Command.TaggedKey.Type,
    name = Artifact.Type.Daemon,
    version = "",
    new_tag = "",
    step_key = "promote-docker",
    profile = Profiles.Type.Standard,
    `if` = None B/If
  }
}


let promoteDebianStep = \(spec : PromoteDebianSpec.Type) ->
    Command.build
      Command.Config::{
        commands = DebianVersions.toolchainRunner DebianVersions.DebVersion.Bullseye spec.profile [
            "AWS_ACCESS_KEY_ID",
            "AWS_SECRET_ACCESS_KEY"
        ] "./buildkite/scripts/promote-deb.sh --package ${Package.debianName spec.package}${Profiles.toLabelSegment spec.profile} --version ${spec.version} --new-version ${spec.new_version} --architecture ${spec.architecture} --codename ${DebianVersions.lowerName spec.codename} --from-component ${DebianChannel.lowerName spec.from_channel} --to-component ${DebianChannel.lowerName spec.to_channel}",
        label = "Debian: ${spec.step_key}",
        key = spec.step_key,
        target = Size.XLarge,
        depends_on = spec.deps,
        `if` = spec.`if`
      }

let promoteDockerStep = \(spec : PromoteDockerSpec.Type) ->
    Command.build
      Command.Config::{
        commands = [ 
          Cmd.run "./buildkite/scripts/promote-docker.sh --name ${Artifact.dockerName spec.name}${Profiles.toLabelSegment spec.profile} --version ${spec.version} --tag ${spec.new_tag}"
        ],
        label = "Docker: ${spec.step_key}",
        key = spec.step_key,
        target = Size.XLarge,
        depends_on = spec.deps,
        `if` = spec.`if`
      }


let pipeline : List PromoteDebianSpec.Type -> 
   List PromoteDockerSpec.Type -> 
   DebianVersions.DebVersion -> 
   PipelineMode.Type -> 
   Pipeline.Config.Type =   
  \(debians_spec : List PromoteDebianSpec.Type) -> 
  \(dockers_spec : List PromoteDockerSpec.Type) -> 
  \(debVersion: DebianVersions.DebVersion) -> 
  \(mode: PipelineMode.Type) ->
     
    let steps = 
        (List/map
            PromoteDebianSpec.Type
            Command.Type
            (\(spec: PromoteDebianSpec.Type ) -> promoteDebianStep spec )
            debians_spec
        )
         #
         (List/map
            PromoteDockerSpec.Type
            Command.Type
            (\(spec: PromoteDockerSpec.Type ) -> promoteDockerStep spec )
            dockers_spec
          )
    in
    --- tags are empty on purpose not to allow run job from automatically triggered pipelines
    Pipeline.Config::{
      spec =
        JobSpec::{
          dirtyWhen = DebianVersions.dirtyWhen debVersion,
          path = "Release",
          name = "PromotePackage",
          tags = []: List PipelineTag.Type,
          mode = mode
        },
      steps = steps
    }
in

{ promoteDebianStep = promoteDebianStep
  , promoteDockerStep = promoteDockerStep
  , pipeline = pipeline
  , PromoteDebianSpec = PromoteDebianSpec 
  , PromoteDockerSpec = PromoteDockerSpec
}