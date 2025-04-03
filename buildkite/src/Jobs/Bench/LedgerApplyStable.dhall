let LedgerApply = ../../Command/Bench/LedgerApply.dhall

let PipelineMode = ../../Pipeline/Mode.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      ( LedgerApply.pipeline
          LedgerApply.Spec::{
          , name = "LedgerApplyStable"
          , label = "Ledger Apply"
          , key = "ledger-apply"
          , mode = PipelineMode.Type.Stable
          }
      )
