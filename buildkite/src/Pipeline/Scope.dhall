-- Scope defines pipeline run scope
--
-- Scope of the pipeline can be either PullRequest, Nightly, MainlineNightly or Release.
-- PullRequest - run pipeline for pull request
-- Nightly - run pipeline for nightly changes
-- MainlineNightly - run pipeline for mainline nightly changes
-- Release - run pipeline for release changes
--
-- Scope is used to determine which jobs should be run in the pipeline.
-- We can see scope as specialized tag that is applied to jobs. Single job can have multiple scopes.
-- On Pipeline top level we can filter jobs based on scope, tags and mode.

let Prelude = ../External/Prelude.dhall

let Extensions = ../Lib/Extensions.dhall

let Scope = < PullRequest | Nightly | MainlineNightly | Release >

let capitalName =
          \(scope : Scope)
      ->  merge
            { PullRequest = "PullRequest"
            , Nightly = "Nightly"
            , MainlineNightly = "MainlineNightly"
            , Release = "Release"
            }
            scope

let lowerName =
          \(scope : Scope)
      ->  merge
            { PullRequest = "pullrequest"
            , Nightly = "nightly"
            , MainlineNightly = "mainlinenightly"
            , Release = "release"
            }
            scope

let join =
          \(scopes : List Scope)
      ->  Extensions.join "," (Prelude.List.map Scope Text lowerName scopes)

let Full =
      [ Scope.PullRequest, Scope.Nightly, Scope.MainlineNightly, Scope.Release ]

let PullRequestOnly = [ Scope.PullRequest ]

let AllButPullRequest = [ Scope.Nightly, Scope.MainlineNightly, Scope.Release ]

in  { Type = Scope
    , Full = Full
    , PullRequestOnly = PullRequestOnly
    , AllButPullRequest = AllButPullRequest
    , capitalName = capitalName
    , lowerName = lowerName
    , join = join
    }
