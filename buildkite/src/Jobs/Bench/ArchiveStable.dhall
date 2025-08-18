let ArchiveBench = ../../Command/Bench/Archive.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

in  ArchiveBench.makeArchiveBench
      "ArchiveStable"
      PipelineScope.AllButPullRequest
