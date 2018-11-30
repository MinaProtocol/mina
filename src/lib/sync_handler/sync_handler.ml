open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus_mechanism_intf

  module Merkle_address : Merkle_address.S

  module Staged_ledger : sig
    type t
  end

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t
     and type merkle_tree := Staged_ledger.t

  module Transition_frontier :
    Transition_frontier_intf with type staged_ledger := Staged_ledger.t
end

module Make (Inputs : Inputs_intf) :
  Sync_handler_intf
  with type addr := Inputs.Merkle_address.t
   and type hash := Inputs.Transition_frontier.state_hash
   and type syncable_ledger := Inputs.Syncable_ledger.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer
   and type transition_frontier := Inputs.Transition_frontier.t = struct
  open Inputs

  let answer_query ~frontier (hash, query) =
    let open Option.Let_syntax in
    let%map breadcrumb = Transition_frontier.find frontier hash in
    let ledger = Transition_frontier.Breadcrumb.staged_ledger breadcrumb in
    let responder = Syncable_ledger.Responder.create ledger ignore in
    let answer = Syncable_ledger.Responder.answer_query responder query in
    (hash, answer)

  let run ~frontier ~sync_query_reader ~sync_answer_writer =
    let answer_broadcaster =
      Strict_pipe.Reader.filter_map sync_query_reader
        ~f:(answer_query ~frontier)
    in
    Strict_pipe.transfer answer_broadcaster sync_answer_writer ~f:Fn.id
    |> don't_wait_for
end
