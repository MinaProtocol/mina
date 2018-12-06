open Core_kernel
open Async_kernel
open Pipe_lib
open Protocols.Coda_transition_frontier
open Coda_base

module type Inputs_intf = sig
  include Transition_frontier.Inputs_intf

  module Transition_frontier :
    Transition_frontier_intf
    with type state_hash := State_hash.t
     and type external_transition := External_transition.t
     and type ledger_database := Ledger.Db.t
     and type ledger_builder := Ledger_builder.t
     and type masked_ledger := Ledger.Mask.Attached.t

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Ledger.Addr.t
     and type hash := Ledger_hash.t
     and type merkle_tree := Ledger.Mask.Attached.t
     and type merkle_path := Ledger.path
     and type root_hash := Ledger_hash.t
     and type account := Account.t
end

module Make (Inputs : Inputs_intf) :
  Sync_handler_intf
  with type addr := Ledger.Addr.t
   and type hash := State_hash.t
   and type syncable_ledger := Inputs.Syncable_ledger.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer
   and type transition_frontier := Inputs.Transition_frontier.t = struct
  open Inputs

  let answer_query ~frontier (hash, query) =
    let open Option.Let_syntax in
    let%map breadcrumb = Transition_frontier.find frontier hash in
    let staged_ledger =
      Transition_frontier.Breadcrumb.staged_ledger breadcrumb
    in
    let ledger = Transition_frontier.Staged_ledger.ledger staged_ledger in
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
