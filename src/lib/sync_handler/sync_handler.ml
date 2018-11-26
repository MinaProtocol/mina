open Core_kernel
open Async_kernel
open Protocols.Coda_pow
open Coda_base
open Pipe_lib

module type Inputs_intf = sig
  module Consensus_mechanism : Consensus_mechanism_intf

  module Merkle_address : Merkle_address.S

  module Syncable_ledger :
    Syncable_ledger.S
    with type addr := Merkle_address.t
     and type hash := Ledger_hash.t

  module Transition_frontier : Transition_frontier_intf
end

module Make (Inputs : Inputs_intf) :
  Sync_handler_intf
  with type addr := Inputs.Merkle_address.t
   and type hash := Ledger_hash.t
   and type syncable_ledger := Inputs.Syncable_ledger.t
   and type syncable_ledger_query := Inputs.Syncable_ledger.query
   and type syncable_ledger_answer := Inputs.Syncable_ledger.answer
   and type transition_frontier := Inputs.Transition_frontier.t = struct
  let run ~sync_query_reader ~sync_answer_writer:_ _transition_frontier =
    don't_wait_for
      (Strict_pipe.Reader.iter sync_query_reader ~f:(fun _ ->
           failwith "Intentionally unimplemented sync_handler" ))
end
