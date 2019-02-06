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
     and type transaction := Transaction.t
     and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
     and type staged_ledger_diff := Staged_ledger_diff.t
     and type consensus_local_state := Consensus.Local_state.t
end

module Make (Inputs : Inputs_intf) :
  Sync_handler_intf
  with type state_hash := State_hash.t
   and type ledger_hash := Ledger_hash.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type ancestor_proof := State_body_hash.t list
   and type external_transition := Inputs.External_transition.t
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

  let answer_query ~frontier hash query =
    let open Option.Let_syntax in
    let%map ledger = get_ledger_by_hash ~frontier hash in
    let responder = Sync_ledger.Responder.create ledger ignore in
    let answer = Sync_ledger.Responder.answer_query responder query in
    (hash, answer)

  let prove_ancestry ~frontier generations descendant =
    let open Option.Let_syntax in
    let rec create_proof acc iter_traversal state_hash =
      if iter_traversal = 0 then Some (state_hash, acc)
      else
        let%bind breadcrumb = Transition_frontier.find frontier state_hash in
        let transition_with_hash =
          Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
        in
        let external_transition = With_hash.data transition_with_hash in
        let protocol_state =
          External_transition.Verified.protocol_state external_transition
        in
        let body = External_transition.Protocol_state.body protocol_state in
        let state_body_hash =
          External_transition.Protocol_state.Body.hash body
        in
        let previous_state_hash =
          External_transition.Protocol_state.previous_state_hash protocol_state
        in
        create_proof (state_body_hash :: acc) (iter_traversal - 1)
          previous_state_hash
    in
    let%bind state_hash, proof = create_proof [] generations descendant in
    let%map transition_with_hash =
      Transition_frontier.find frontier state_hash
    in
    let external_transition =
      transition_with_hash
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.data
      |> External_transition.of_verified
    in
    (external_transition, proof)
end
