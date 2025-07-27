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

let List/any = Prelude.List.any

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

let toNatural =
          \(scope : Scope)
      ->  merge
            { PullRequest = 0, Nightly = 1, MainlineNightly = 2, Release = 3 }
            scope

let equal
    : Scope -> Scope -> Bool
    =     \(left : Scope)
      ->  \(right : Scope)
      ->  Prelude.Natural.equal (toNatural left) (toNatural right)

let hasAny
    : Scope -> List Scope -> Bool
    =     \(input : Scope)
      ->  \(scopes : List Scope)
      ->  List/any Scope (\(x : Scope) -> equal x input) scopes

let hasPullRequest
    : List Scope -> Bool
    = \(scopes : List Scope) -> hasAny Scope.PullRequest scopes

let contains
    : List Scope -> List Scope -> Bool
    =     \(input : List Scope)
      ->  \(scopes : List Scope)
      ->  List/any Scope (\(x : Scope) -> hasAny x scopes) input

let Full =
      [ Scope.PullRequest, Scope.Nightly, Scope.MainlineNightly, Scope.Release ]

let PullRequestOnly = [ Scope.PullRequest ]

let AllButPullRequest = [ Scope.Nightly, Scope.MainlineNightly, Scope.Release ]

in  { Type = Scope
    , Full = Full
    , PullRequestOnly = PullRequestOnly
    , AllButPullRequest = AllButPullRequest
    , hasPullRequest = hasPullRequest
    , capitalName = capitalName
    , lowerName = lowerName
    , toNatural = toNatural
    , equal = equal
    , hasAny = hasAny
    , contains = contains
    }
