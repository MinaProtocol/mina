open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  module Merkle_address : Merkle_address.S

  module Staged_ledger : sig
    type t
  end

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t
     and type merkle_tree := Staged_ledger.t

  module Protocol_state : Protocol_state.S

  module External_transition :
    External_transition_intf with type protocol_state := Protocol_state.value

  module Transition_frontier :
    Transition_frontier_intf
    with type staged_ledger := Staged_ledger.t
     and type external_transition := External_transition.t
     and type state_hash := State_hash.t
end

module Make (Inputs : Inputs_intf) :
  Sync_handler_intf
  with type addr := Inputs.Merkle_address.t
   and type hash := State_hash.t
   and type syncable_ledger := Inputs.Syncable_ledger.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer
   and type transition_frontier := Inputs.Transition_frontier.t
   and type ancestor_proof := State_body_hash.t list = struct
  open Inputs

  let answer_query ~frontier (hash, query) =
    let open Option.Let_syntax in
    let%map breadcrumb = Transition_frontier.find frontier hash in
    let ledger = Transition_frontier.Breadcrumb.staged_ledger breadcrumb in
    let responder = Syncable_ledger.Responder.create ledger ignore in
    let answer = Syncable_ledger.Responder.answer_query responder query in
    (hash, answer)

  let prove_ancestory ~frontier generations descendants =
    let open Option.Let_syntax in
    let rec go acc iter_traversal state_hash =
      if iter_traversal = 0 then Some (state_hash, acc)
      else
        let%bind breadcrumb = Transition_frontier.find frontier state_hash in
        let transition_with_hash =
          Transition_frontier.Breadcrumb.transition_with_hash breadcrumb
        in
        let external_transition = With_hash.data transition_with_hash in
        let protocol_state =
          External_transition.protocol_state external_transition
        in
        let body = Protocol_state.body protocol_state in
        let state_body_hash = Protocol_state.Body.hash body in
        let previous_state_hash =
          Protocol_state.previous_state_hash protocol_state
        in
        go (state_body_hash :: acc) (iter_traversal - 1) previous_state_hash
    in
    go [] generations descendants

  let run ~frontier ~sync_query_reader ~sync_answer_writer =
    let answer_broadcaster =
      Strict_pipe.Reader.filter_map sync_query_reader
        ~f:(answer_query ~frontier)
    in
    Strict_pipe.transfer answer_broadcaster sync_answer_writer ~f:Fn.id
    |> don't_wait_for
end
