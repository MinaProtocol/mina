let LedgerApply = ../../Command/Bench/LedgerApply.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      ( LedgerApply.pipeline
          LedgerApply.Spec::{
          , name = "LedgerApplyUnstable"
          , label = "Ledger Apply"
          , key = "ledger-apply"
          }
      )
