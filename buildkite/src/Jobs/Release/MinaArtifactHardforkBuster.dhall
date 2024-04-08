let HardforkPackageGeneration = ../../Command/HardforkPackageGeneration.dhall

let DebianVersions = ../../Constants/DebianVersions.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build (HardforkPackageGeneration.pipeline DebianVersions.DebVersion.Buster)
