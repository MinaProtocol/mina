let Prelude = ./External/Prelude.dhall

let List/map = Prelude.List.map

let SelectFiles = ./Lib/SelectFiles.dhall

let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall

let Docker = ./Command/Docker/Type.dhall

let JobSpec = ./Pipeline/JobSpec.dhall

let Pipeline = ./Pipeline/Dsl.dhall

let PipelineJobSelection = ./Pipeline/JobSelection.dhall

let PipelineTagFilter = ./Pipeline/TagFilter.dhall

let PipelineTag = ./Pipeline/Tag.dhall

let PipelineScope = ./Pipeline/Scope.dhall

let PipelineScopeFilter = ./Pipeline/ScopeFilter.dhall

let Size = ./Command/Size.dhall

let triggerCommand = ./Pipeline/TriggerCommand.dhall

let jobs
    : List JobSpec.Type
    = List/map
        Pipeline.CompoundType
        JobSpec.Type
        (\(composite : Pipeline.CompoundType) -> composite.spec)
        ./gen/Jobs.dhall

let prefixCommands =
      [ Cmd.run
          "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt"
      , Cmd.run "./buildkite/scripts/refresh_code.sh"
      , Cmd.run "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
      ]

let commands
    :     PipelineJobSelection.Type
      ->  PipelineTagFilter.Type
      ->  PipelineScopeFilter.Type
      ->  List Cmd.Type
    =     \(selection : PipelineJobSelection.Type)
      ->  \(filter : PipelineTagFilter.Type)
      ->  \(scope : PipelineScopeFilter.Type)
      ->  List/map
            JobSpec.Type
            Cmd.Type
            (     \(job : JobSpec.Type)
              ->  let targetTags = PipelineTagFilter.tags filter

                  let jobsFilter = PipelineTagFilter.show filter

                  let isIncludedInTag =
                        Prelude.Bool.show
                          (PipelineTag.contains job.tags targetTags)

                  let targetScopes = PipelineScopeFilter.tags scope

                  let scopeFilter = PipelineScopeFilter.show scope

                  let isIncludedInScope =
                        Prelude.Bool.show
                          (PipelineScope.contains job.scope targetScopes)

                  let dirtyWhen = SelectFiles.compile job.dirtyWhen

                  let trigger =
                        triggerCommand "src/Jobs/${job.path}/${job.name}.dhall"

                  let pipelineHandlers =
                        { Triaged =
                            ''
                              if [ "${isIncludedInTag}" == "False" ]; then
                                echo "Skipping ${job.name} because this job is not falling under ${jobsFilter} filter "
                              elif [ "${isIncludedInScope}" == "False" ]; then
                                echo "Skipping ${job.name} because this is job is not falling under ${scopeFilter} stage"
                              elif (cat _computed_diff.txt | egrep -q '${dirtyWhen}'); then
                                echo "Triggering ${job.name} for reason:"
                                cat _computed_diff.txt | egrep '${dirtyWhen}'
                                ${Cmd.format trigger}
                              else
                                echo "Skipping ${job.name} because is irrelevant to PR changes"
                              fi
                            ''
                        , Full =
                            ''
                              if [ "${isIncludedInTag}" == "False" ]; then
                                echo "Skipping ${job.name} because this job is not falling under ${jobsFilter} filter "
                              elif [ "${isIncludedInScope}" == "False" ]; then
                                echo "Skipping ${job.name} because this is job is not falling under ${scopeFilter} stage"
                              else
                                echo "Triggering ${job.name} because this is a stable buildkite run"
                                ${Cmd.format trigger}
                              fi
                            ''
                        }

                  in  Cmd.quietly (merge pipelineHandlers selection)
            )
            jobs

in      \ ( args
          : { selection : PipelineJobSelection.Type
            , tagFilter : PipelineTagFilter.Type
            , scopeFilter : PipelineScopeFilter.Type
            }
          )
    ->  let pipelineType =
              Pipeline.build
                Pipeline.Config::{
                , spec = JobSpec::{
                  , name =
                      "monorepo-triage-${PipelineTagFilter.show
                                           args.tagFilter}-${PipelineScopeFilter.show
                                                               args.scopeFilter}-${PipelineJobSelection.capitalName
                                                                                     args.selection}"
                  , dirtyWhen = [ SelectFiles.everything ]
                  }
                , steps =
                  [ Command.build
                      Command.Config::{
                      , commands =
                            prefixCommands
                          # commands
                              args.selection
                              args.tagFilter
                              args.scopeFilter
                      , label =
                          "Monorepo triage ${PipelineTagFilter.show
                                               args.tagFilter} ${PipelineScopeFilter.show
                                                                   args.scopeFilter} ${PipelineJobSelection.capitalName
                                                                                         args.selection}"
                      , key =
                          "cmds-${PipelineTagFilter.show
                                    args.tagFilter}-${PipelineScopeFilter.show
                                                        args.scopeFilter}-${PipelineJobSelection.capitalName
                                                                              args.selection}"
                      , target = Size.Multi
                      , docker = Some Docker::{
                        , image =
                            (./Constants/ContainerImages.dhall).toolchainBase
                        , environment =
                          [ "BUILDKITE_AGENT_ACCESS_TOKEN"
                          , "BUILDKITE_INCREMENTAL"
                          ]
                        }
                      }
                  ]
                }

        in  pipelineType.pipeline
