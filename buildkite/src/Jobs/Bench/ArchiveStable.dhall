let ArchiveBench = ../../Command/Bench/Archive.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

in  ArchiveBench.makeArchiveBench "ArchiveStable" PipelineMode.Type.Stable
