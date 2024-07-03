let HardforkPackageGeneration = ../../Command/HardforkPackageGeneration.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      (HardforkPackageGeneration.pipeline HardforkPackageGeneration.Spec::{=})
