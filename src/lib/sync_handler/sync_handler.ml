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
     and type user_command := User_command.t

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
   and type state_hash := State_hash.t
   and type external_transition := Inputs.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type syncable_ledger_query := Sync_ledger.Query.t
   and type syncable_ledger_answer := Sync_ledger.Answer.t = struct
  open Inputs

  let get_breadcrumb_ledgers frontier =
    List.map
      (Transition_frontier.all_breadcrumbs frontier)
      ~f:
        (Fn.compose Staged_ledger.ledger
           Transition_frontier.Breadcrumb.staged_ledger)

  let get_ledger_by_hash ~frontier ledger_hash =
    let ledger_breadcrumbs =
      Sequence.of_lazy
        (lazy (Sequence.of_list @@ get_breadcrumb_ledgers frontier))
    in
    Sequence.append
      (Sequence.singleton
         (Transition_frontier.shallow_copy_root_snarked_ledger frontier))
      ledger_breadcrumbs
    |> Sequence.find ~f:(fun ledger ->
           Ledger_hash.equal (Ledger.merkle_root ledger) ledger_hash )

  let answer_query ~frontier hash query ~logger =
    let open Option.Let_syntax in
    let%map ledger = get_ledger_by_hash ~frontier hash in
    let responder = Sync_ledger.Mask.Responder.create ledger ignore ~logger in
    let answer = Sync_ledger.Mask.Responder.answer_query responder query in
    (hash, answer)

  let transition_catchup ~frontier state_hash =
    let open Option.Let_syntax in
    let%bind transitions =
      Transition_frontier.root_history_path_map frontier
        ~f:(fun b ->
          Transition_frontier.Breadcrumb.transition_with_hash b
          |> With_hash.data |> External_transition.of_verified )
        state_hash
    in
    let length =
      Int.min
        (Non_empty_list.length transitions)
        (2 * Transition_frontier.max_length)
    in
    Non_empty_list.take (Non_empty_list.rev transitions) length
    >>| Non_empty_list.rev
end
