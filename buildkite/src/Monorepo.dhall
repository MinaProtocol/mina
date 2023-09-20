let Prelude = ./External/Prelude.dhall
let List/map = Prelude.List.map
let List/filter = Prelude.List.filter


let SelectFiles = ./Lib/SelectFiles.dhall
let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall
let Docker = ./Command/Docker/Type.dhall
let JobSpec = ./Pipeline/JobSpec.dhall
let Pipeline = ./Pipeline/Dsl.dhall
let PipelineMode = ./Pipeline/Mode.dhall
let PipelineStage = ./Pipeline/Stage.dhall
let Size = ./Command/Size.dhall
let triggerCommand = ./Pipeline/TriggerCommand.dhall

let mode = env:BUILDKITE_PIPELINE_MODE as Text ? "PullRequest"
let stage = env:BUILDKITE_PIPELINE_STAGE as Text ? "Test"

let jobs : List JobSpec.Type =
  List/map
    Pipeline.CompoundType
    JobSpec.Type
    (\(composite: Pipeline.CompoundType) -> composite.spec)
    ./gen/Jobs.dhall

let prefixCommands = [
  Cmd.run "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt", -- Tell git where to find certs for https connections
  Cmd.run "git fetch origin", -- Freshen the cache
  Cmd.run "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
]


-- Run a job if we touched a dirty path
let commands: Text -> Text -> List Cmd.Type  =  \(targetStage: Text) -> \(targetMode: Text) ->
  Prelude.List.map 
    JobSpec.Type 
    Cmd.Type 
    (\(job: JobSpec.Type) ->
      let jobMode = PipelineMode.capitalName job.mode
      let jobStage = PipelineStage.capitalName job.stage

      let dirtyWhen = SelectFiles.compile job.dirtyWhen
      let trigger = triggerCommand "src/Jobs/${job.path}/${job.name}.dhall"
      let pipelineHandlers = {
        PullRequest = ''
          if [ "${targetMode}" == "PullRequest" ]; then
            if [ "${jobStage}" == "${targetStage}" ]; then
              if (cat _computed_diff.txt | egrep -q '${dirtyWhen}'); then
                echo "Triggering ${job.name} for reason:"
                cat _computed_diff.txt | egrep '${dirtyWhen}'
                ${Cmd.format trigger}
              fi
            else
              echo "Skipping ${job.name} because this is a ${targetStage} stage"
            fi
          else 
            if [ "${jobStage}" == "${targetStage}" ]; then
              echo "Triggering ${job.name} because this is a stable buildkite run"
              ${Cmd.format trigger}
            else 
              echo "Skipping ${job.name} because this is a ${targetStage} stage"
            fi
          fi
        '',
        Stable = ''
          if [ "${targetMode}" == "PullRequest" ]; then
            echo "Skipping ${job.name} because this is a PR buildkite run"
          else 
            if [ "${jobStage}" == "${targetStage}" ]; then
              echo "Triggering ${job.name} because this is a stable buildkite run"
              ${Cmd.format trigger}
            else
              echo "Skipping ${job.name} because this is a ${targetStage} stage"
            fi
          fi
        ''
      }
      in Cmd.quietly (merge pipelineHandlers job.mode)
    ) 
    jobs

in Pipeline.build Pipeline.Config::{
  spec = JobSpec::{
    name = "monorepo-triage",
    -- TODO: Clean up this code so we don't need an unused dirtyWhen here
    dirtyWhen = [ SelectFiles.everything ]
  },
  steps = [
  Command.build
    Command.Config::{
      commands = prefixCommands # (commands stage mode),
      label = "Monorepo triage ${stage}",
      key = "cmds-${stage}",
      target = Size.Small,
      docker = Some Docker::{
        image = (./Constants/ContainerImages.dhall).toolchainBase,
        environment = ["BUILDKITE_AGENT_ACCESS_TOKEN", "BUILDKITE_INCREMENTAL"]
      }
    }
  ]
}
