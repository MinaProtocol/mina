let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall
let D = S.PathPattern

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall


let dependsOn = [
    { name = "MinaArtifactBullseye", key = "build-deb-pkg" }
]

in 

let buildTestCmd : Text -> Size -> List Command.TaggedKey.Type -> Command.Type = \(release_branch : Text) -> \(cmd_target : Size) -> \(dependsOn : List Command.TaggedKey.Type) ->
  Command.build
    Command.Config::{
      commands =  [
        Cmd.runInDocker
            Cmd.Docker::{
              image = (../../Constants/ContainerImages.dhall).ubuntu2004
            } "buildkite/scripts/dump-mina-type-shapes.sh",
        Cmd.run "gsutil cp $(git log -n 1 --format=%h --abbrev=7 --no-merges)-type_shape.txt $MINA_TYPE_SHAPE gs://mina-type-shapes",
        Cmd.runInDocker
            Cmd.Docker::{
              image = (../../Constants/ContainerImages.dhall).ubuntu2004
            } "buildkite/scripts/version-linter.sh ${release_branch}"
      ],
      label = "Versioned type linter",
      key = "version-linter",
      target = cmd_target,
      docker = None Docker.Type,
      tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
      depends_on = dependsOn,
      artifact_paths = [ S.contains "core_dumps/*" ]
    }
in

Pipeline.build
  Pipeline.Config::{
    spec =
      let lintDirtyWhen = [
        S.strictlyStart (S.contains "src"),
        S.exactly "buildkite/src/Jobs/Test/VersionLint" "dhall",
        S.exactly "buildkite/scripts/version_linter" "sh"
      ]

      in

      JobSpec::{
        dirtyWhen = lintDirtyWhen,
        path = "Test",
        name = "VersionLint",
        tags = [ PipelineTag.Type.Long, PipelineTag.Type.Test ]
      },
    steps = [
      buildTestCmd "develop" Size.Small dependsOn
    ]
  }