let ArchiveBench = ../../Command/Bench/Archive.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

in  ArchiveBench.makeArchiveBench
      "ArchiveUnstable"
      PipelineMode.Type.PullRequest
