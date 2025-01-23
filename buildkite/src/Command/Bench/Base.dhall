let PipelineMode = ../../Pipeline/Mode.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Profiles = ../../Constants/Profiles.dhall

let Command = ../../Command/Base.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../Size.dhall

let Benchmarks = ../../Constants/Benchmarks.dhall

let SelectFiles = ../../Lib/SelectFiles.dhall

let Spec =
      { Type =
          { key : Text
          , bench : Text
          , label : Text
          , size : Size
          , name : Text
          , path : Text
          , mode : PipelineMode.Type
          , dependsOn : List Command.TaggedKey.Type
          , additionalDirtyWhen : List SelectFiles.Type
          , yellowThreshold : Double
          , redThreshold : Double
          }
      , default =
          { mode = PipelineMode.Type.PullRequest
          , size = Size.Medium
          , dependsOn =
              DebianVersions.dependsOn
                DebianVersions.DebVersion.Bullseye
                Profiles.Type.Standard
          , additionalDirtyWhen = [] : List SelectFiles.Type
          , yellowThreshold = 0.1
          , redThreshold = 0.2
          }
      }

let command
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  (Benchmarks.toEnvList Benchmarks.Type::{=})
                  "./buildkite/scripts/benchmarks.sh  ${spec.bench} --red-threshold ${Double/show
                                                                                        spec.redThreshold} --yellow-threshold ${Double/show
                                                                                                                                  spec.yellowThreshold}"
            , label = "Perf: ${spec.label}"
            , key = spec.key
            , target = spec.size
            , docker = None Docker.Type
            , depends_on = spec.dependsOn
            }

let pipeline
    : Spec.Type -> Pipeline.Config.Type
    =     \(spec : Spec.Type)
      ->  Pipeline.Config::{
          , spec = JobSpec::{
            , dirtyWhen =
                  [ SelectFiles.strictlyStart (SelectFiles.contains "src")
                  , SelectFiles.exactly
                      "buildkite/src/Command/Bench/Base"
                      "dhall"
                  , SelectFiles.contains "scripts/benchmark"
                  , SelectFiles.contains "buildkite/scripts/benchmark"
                  ]
                # spec.additionalDirtyWhen
            , path = spec.path
            , name = spec.name
            , mode = spec.mode
            , tags =
              [ PipelineTag.Type.Long
              , PipelineTag.Type.Test
              , PipelineTag.Type.Stable
              ]
            }
          , steps = [ command spec ]
          }

in  { command = command, pipeline = pipeline, Spec = Spec }
