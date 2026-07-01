-- Scope defines pipeline run scope
--
-- Scope of the pipeline can be either PullRequest, Nightly, MainlineNightly, Weekly or Release.
-- PullRequest - run pipeline for pull request
-- Nightly - run pipeline for nightly changes
-- MainlineNightly - run pipeline for mainline nightly changes
-- Weekly - run pipeline for the weekly full-matrix sweep (all distros/dockers/debians)
-- Release - run pipeline for release changes
--
-- Scope is used to determine which jobs should be run in the pipeline.
-- We can see scope as specialized tag that is applied to jobs. Single job can have multiple scopes.
-- On Pipeline top level we can filter jobs based on scope, tags and mode.

let Prelude = ../External/Prelude.dhall

let Extensions = ../Lib/Extensions.dhall

let Scope =
      < PullRequest
      | Nightly
      | MainlineNightly
      | Weekly
      | Release
      | BootstrapRelease
      >

let capitalName =
          \(scope : Scope)
      ->  merge
            { PullRequest = "PullRequest"
            , Nightly = "Nightly"
            , MainlineNightly = "MainlineNightly"
            , Weekly = "Weekly"
            , Release = "Release"
            , BootstrapRelease = "BootstrapRelease"
            }
            scope

let lowerName =
          \(scope : Scope)
      ->  merge
            { PullRequest = "pullrequest"
            , Nightly = "nightly"
            , MainlineNightly = "mainlinenightly"
            , Weekly = "weekly"
            , Release = "release"
            , BootstrapRelease = "bootstraprelease"
            }
            scope

let join =
          \(scopes : List Scope)
      ->  Extensions.join "," (Prelude.List.map Scope Text lowerName scopes)

let Full =
      [ Scope.PullRequest
      , Scope.Nightly
      , Scope.MainlineNightly
      , Scope.Weekly
      , Scope.Release
      ]

let PullRequestOnly = [ Scope.PullRequest ]

let AllButPullRequest =
      [ Scope.Nightly, Scope.MainlineNightly, Scope.Weekly, Scope.Release ]

in  { Type = Scope
    , Full = Full
    , PullRequestOnly = PullRequestOnly
    , AllButPullRequest = AllButPullRequest
    , capitalName = capitalName
    , lowerName = lowerName
    , join = join
    }
