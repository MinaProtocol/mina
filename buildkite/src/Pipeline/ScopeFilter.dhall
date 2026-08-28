-- Tag defines pipeline
-- Using tags one can tailor pipeline for any need. Each job should be tagged with one or several tags
-- then on pipeline settings we can define which tagged jobs to include or exclue in pipeline

let Scope = ./Scope.dhall

let Filter
    : Type
    = < PullRequestOnly
      | StableOnly
      | Nightly
      | MainlineNightly
      | Weekly
      | Release
      | BootstrapOnly
      | All
      >

let scopes
    : Filter -> List Scope.Type
    =     \(filter : Filter)
      ->  merge
            { PullRequestOnly = [ Scope.Type.PullRequest ]
            , StableOnly = [ Scope.Type.MainlineNightly, Scope.Type.Release ]
            , Nightly = [ Scope.Type.Nightly ]
            , MainlineNightly = [ Scope.Type.MainlineNightly ]
            , Weekly = [ Scope.Type.Weekly ]
            , Release = [ Scope.Type.Release ]
            , BootstrapOnly = [ Scope.Type.BootstrapRelease ]
            , All =
              [ Scope.Type.PullRequest
              , Scope.Type.Nightly
              , Scope.Type.MainlineNightly
              , Scope.Type.Weekly
              , Scope.Type.Release
              ]
            }
            filter

let show
    : Filter -> Text
    =     \(filter : Filter)
      ->  merge
            { PullRequestOnly = "pullrequestonly"
            , StableOnly = "stableonly"
            , Nightly = "nightly"
            , MainlineNightly = "mainlinenightly"
            , Weekly = "weekly"
            , Release = "release"
            , BootstrapOnly = "bootstraponly"
            , All = "all"
            }
            filter

in  { Type = Filter, scopes = scopes, show = show }
