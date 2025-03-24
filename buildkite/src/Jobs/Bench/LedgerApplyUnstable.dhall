let LedgerApply = ../../Command/Bench/LedgerApply.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      ( LedgerApply.pipeline
          LedgerApply.Spec::{
          , name = "LedgerApplyUnstable"
          , label = "Ledger Apply Unstable"
          , key = "ledger-apply-unstable"
          , mode = PipelineMode.Type.Stable
          }
      )
