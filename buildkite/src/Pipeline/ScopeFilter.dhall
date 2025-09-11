-- Tag defines pipeline
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclue in pipeline

let Scope = ./Scope.dhall

let Filter
    : Type
    = < PullRequestOnly | StableOnly | Nightly | MainlineNightly | All >

let tags
    : Filter -> List Scope.Type
    =     \(filter : Filter)
      ->  merge
            { PullRequestOnly = [ Scope.Type.PullRequest ]
            , StableOnly = [ Scope.Type.MainlineNightly, Scope.Type.Release ]
            , Nightly = [ Scope.Type.Nightly ]
            , MainlineNightly = [ Scope.Type.MainlineNightly ]
            , All =
              [ Scope.Type.PullRequest
              , Scope.Type.Nightly
              , Scope.Type.MainlineNightly
              , Scope.Type.Release
              ]
            }
            filter

let show
    : Filter -> Text
    =     \(filter : Filter)
      ->  merge
            { PullRequestOnly = "PullRequestOnly"
            , StableOnly = "StableOnly"
            , Nightly = "Nightly"
            , MainlineNightly = "MainlineNightly"
            , All = "All"
            }
            filter

in  { Type = Filter, tags = tags, show = show }
