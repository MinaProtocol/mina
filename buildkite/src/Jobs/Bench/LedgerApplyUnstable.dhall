let LedgerApply = ../../Command/Bench/LedgerApply.dhall

let PipelineScope = ../../Pipeline/Scope.dhall

let Pipeline = ../../Pipeline/Dsl.dhall

in  Pipeline.build
      ( LedgerApply.pipeline
          LedgerApply.Spec::{
          , name = "LedgerApplyUnstable"
          , scope = PipelineScope.PullRequestOnly
          , label = "Ledger Apply"
          , key = "ledger-apply"
          }
      )
