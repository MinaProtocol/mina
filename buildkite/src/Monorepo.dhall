let SelectFiles = ./Lib/SelectFiles.dhall

let Cmd = ./Lib/Cmds.dhall

let Command = ./Command/Base.dhall

let Docker = ./Command/Docker/Type.dhall

let JobSpec = ./Pipeline/JobSpec.dhall

let Pipeline = ./Pipeline/Dsl.dhall

let PipelineFilterMode = ./Pipeline/FilterMode.dhall

let PipelineJobSelection = ./Pipeline/JobSelection.dhall

let PipelineTagFilter = ./Pipeline/TagFilter.dhall

let PipelineTag = ./Pipeline/Tag.dhall

let PipelineScope = ./Pipeline/Scope.dhall

let PipelineScopeFilter = ./Pipeline/ScopeFilter.dhall

let Size = ./Command/Size.dhall

let prefixCommands =
      [ Cmd.run
          "git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt"
      , Cmd.run "./buildkite/scripts/refresh_code.sh"
      , Cmd.run "./buildkite/scripts/generate-diff.sh > _computed_diff.txt"
      , Cmd.run
          "./buildkite/scripts/dhall/dump_dhall_to_pipelines.sh ./buildkite/src buildkite/src/gen"
      ]

let commands
    :     PipelineJobSelection.Type
      ->  PipelineTagFilter.Type
      ->  PipelineFilterMode.Type
      ->  PipelineScopeFilter.Type
      ->  Cmd.Type
    =     \(selection : PipelineJobSelection.Type)
      ->  \(tagFilter : PipelineTagFilter.Type)
      ->  \(filterMode : PipelineFilterMode.Type)
      ->  \(scopeFilter : PipelineScopeFilter.Type)
      ->  let requestedScopes = PipelineScopeFilter.scopes scopeFilter

          let requestedTags = PipelineTagFilter.tags tagFilter

          in  Cmd.run
                (     "./buildkite/scripts/monorepo.sh"
                  ++  " --scopes ${PipelineScope.join requestedScopes} "
                  ++  " --tags ${PipelineTag.join requestedTags} "
                  ++  " --filter-mode ${PipelineFilterMode.show filterMode} "
                  ++  " --selection-mode ${PipelineJobSelection.show selection} "
                  ++  " --jobs ./buildkite/src/gen"
                  ++  " --git-diff-file _computed_diff.txt "
                )

in      \ ( args
          : { selection : PipelineJobSelection.Type
            , tagFilter : PipelineTagFilter.Type
            , scopeFilter : PipelineScopeFilter.Type
            , filterMode : PipelineFilterMode.Type
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
                          # [ commands
                                args.selection
                                args.tagFilter
                                args.filterMode
                                args.scopeFilter
                            ]
                      , label =
                          "Monorepo triage ${PipelineTagFilter.show
                                               args.tagFilter} ${PipelineScopeFilter.show
                                                                   args.scopeFilter} ${PipelineJobSelection.capitalName
                                                                                         args.selection}"
                      , key = "cmds"
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
