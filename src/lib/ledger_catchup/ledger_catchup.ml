open Core_kernel
open Async_kernel
open Protocols.Coda_transition_frontier
open Pipe_lib
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
end

module Make (Inputs : Inputs_intf) :
  Catchup_intf
  with type external_transition := Inputs.External_transition.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type state_hash := State_hash.t = struct
  let run ~frontier:_ ~catchup_job_reader ~catchup_breadcrumbs_writer:_ =
    don't_wait_for
      (Strict_pipe.Reader.iter catchup_job_reader ~f:(fun _ ->
           failwith "Intentionally unimplemented catchup" ))
end
