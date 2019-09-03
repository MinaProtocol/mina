open Coda_base

module type S = sig
  include Coda_intf.Inputs_intf

  module Transition_frontier :
    Coda_intf.Transition_frontier_intf
    with type external_transition_validated := External_transition.Validated.t
     and type mostly_validated_external_transition :=
                ( [`Time_received] * Truth.true_t
                , [`Proof] * Truth.true_t
                , [`Frontier_dependencies] * Truth.true_t
                , [`Staged_ledger_diff] * Truth.false_t )
                External_transition.Validation.with_transition
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type 'a transaction_snark_work_statement_table := 'a Transaction_snark_work.Statement.Table.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type staged_ledger := Staged_ledger.t
     and type verifier := Verifier.t
end

module With_unprocessed_transition_cache = struct
  module type S = sig
    include S

    module Unprocessed_transition_cache :
      Cache_lib.Intf.Transmuter_cache.S
      with module Cached := Cache_lib.Cached
       and module Cache := Cache_lib.Cache
       and type source =
                  External_transition.with_initial_validation
                  Envelope.Incoming.t
       and type target = State_hash.t
  end
end
