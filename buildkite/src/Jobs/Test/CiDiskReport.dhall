-- Diagnostic job for the recurring CI "no space left on device" failures.
-- Running any toolchain step makes the agent execute load_from_cache.sh, which
-- now prints disk-report.sh (agent-side df + docker system df + largest images)
-- before touching docker -- so this job surfaces what is filling the agent disk.
-- Gated on the disk scripts so it runs whenever we iterate on the experiment.
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

let PipelineTag = ../../Pipeline/Tag.dhall

let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall

let RunInToolchain = ../../Command/RunInToolchain.dhall

let Docker = ../../Command/Docker/Type.dhall

let Size = ../../Command/Size.dhall

in  Pipeline.build
      Pipeline.Config::{
      , spec = JobSpec::{
        , dirtyWhen =
          [ S.exactly "buildkite/scripts/docker/disk-report" "sh"
          , S.exactly "buildkite/scripts/docker/load_from_cache" "sh"
          , S.exactly "buildkite/src/Jobs/Test/CiDiskReport" "dhall"
          ]
        , path = "Test"
        , name = "CiDiskReport"
        , tags = [ PipelineTag.Type.Fast, PipelineTag.Type.Test ]
        }
      , steps =
        [ Command.build
            Command.Config::{
            , commands =
                RunInToolchain.runInToolchain
                  ([] : List Text)
                  "./buildkite/scripts/docker/disk-report.sh"
            , label = "CI: disk usage report"
            , key = "ci-disk-report"
            , target = Size.Small
            , docker = None Docker.Type
            }
        ]
      }
