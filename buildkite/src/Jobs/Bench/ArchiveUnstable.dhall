let ArchiveBench = ../../Command/Bench/Archive.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

in  ArchiveBench.makeArchiveBench
      "ArchiveUnstable"
      PipelineScope.PullRequestOnly
