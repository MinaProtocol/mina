{-|
## RunPerformanceTest Module

A reusable Buildkite command for performance/benchmark jobs that publish their
results to InfluxDB.

The benchmark itself is expressed as `runCommands` — arbitrary command(s) that
produce one or more `*.perf` files (InfluxDB line protocol) under `/workdir`.
This command appends the standard upload teardown (`uploadScript`, run in the
default toolchain with the InfluxDB credentials from `Benchmarks`), so every
perf job uploads the same way instead of open-coding the teardown.

`runCommands` is intentionally open: a job can run its benchmark however it needs
(plain toolchain, `RunWithPostgres`, a Docker container, several steps, …) and
still get the InfluxDB upload for free. Everything else (label, key, size,
artifacts, dependencies, docker, soft-fail, upload script) is a `Spec` field with
a sensible default.

### Example

    RunPerformanceTest.command
      RunPerformanceTest.Spec::{
      , key = "my-bench"
      , label = "My benchmark"
      , runCommands =
        [ RunWithPostgres.runInDockerWithPostgresConn env init image "./my-bench.sh" ]
      }
-}

let Command = ./Base.dhall

let Cmd = ../Lib/Cmds.dhall

let RunInToolchain = ./RunInToolchain.dhall

let Benchmarks = ../Constants/Benchmarks.dhall

let Docker = ./Docker/Type.dhall

let Size = ./Size.dhall

let SelectFiles = ../Lib/SelectFiles.dhall

let B = ../External/Buildkite.dhall

let B/SoftFail = B.definitions/commandStep/properties/soft_fail/Type

let Spec =
      { Type =
          { key : Text
          , label : Text
          , runCommands : List Cmd.Type
          , uploadScript : Text
          , size : Size
          , artifactPaths : List SelectFiles.Type
          , dependsOn : List Command.TaggedKey.Type
          , docker : Optional Docker.Type
          , softFail : Optional B/SoftFail
          }
      , default =
          { uploadScript = "./buildkite/scripts/bench/send.sh"
          , size = Size.Large
          , artifactPaths = [ SelectFiles.contains "*.perf" ]
          , dependsOn = [] : List Command.TaggedKey.Type
          , docker = None Docker.Type
          , softFail = None B/SoftFail
          }
      }

let command
    : Spec.Type -> Command.Type
    =     \(spec : Spec.Type)
      ->  Command.build
            Command.Config::{
            , commands =
                    spec.runCommands
                  # RunInToolchain.runInDefaultToolchain
                      (Benchmarks.toEnvList Benchmarks.Type::{=})
                      spec.uploadScript
            , label = spec.label
            , key = spec.key
            , target = spec.size
            , docker = spec.docker
            , soft_fail = spec.softFail
            , artifact_paths = spec.artifactPaths
            , depends_on = spec.dependsOn
            }

in  { Spec = Spec, command = command }
