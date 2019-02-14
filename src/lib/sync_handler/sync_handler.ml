open Core_kernel
open Protocols.Coda_transition_frontier
open Coda_base

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition_verified := External_transition.Verified.t
     and type ledger_database := Ledger.Db.t
     and type staged_ledger := Staged_ledger.t
     and type masked_ledger := Ledger.Mask.Attached.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type consensus_local_state := Consensus.Local_state.t

  module Time : Protocols.Coda_pow.Time_intf

  module Protocol_state_validator :
    Protocol_state_validator_intf
    with type time := Time.t
     and type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type external_transition_proof_verified :=
                External_transition.Proof_verified.t
     and type external_transition_verified := External_transition.Verified.t
end

module Make (Inputs : Inputs_intf) :
  Sync_handler_intf
  with type ledger_hash := Ledger_hash.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type syncable_ledger_query := Sync_ledger.query
   and type syncable_ledger_answer := Sync_ledger.answer = struct
  open Inputs

  let get_ledger_by_hash ~frontier ledger_hash =
    List.find_map (Transition_frontier.all_breadcrumbs frontier) ~f:(fun b ->
        let ledger =
          Transition_frontier.Breadcrumb.staged_ledger b
          |> Staged_ledger.ledger
        in
        if Ledger_hash.equal (Ledger.merkle_root ledger) ledger_hash then
          Some ledger
        else None )

  let answer_query ~frontier hash query ~logger =
    let open Option.Let_syntax in
    let%map ledger = get_ledger_by_hash ~frontier hash in
    let responder =
      Sync_ledger.Responder.create ledger ignore ~parent_log:logger
    in
    let answer = Sync_ledger.Responder.answer_query responder query in
    (hash, answer)
end
