open Frontier_base

type create_args =
  { db : Database.t; logger : Logger.t; dequeue_snarked_ledger : unit -> unit }

type input = Diff.Lite.E.t list

include
  Otp_lib.Worker_supervisor.S
    with type create_args := create_args
     and type input := input
     and type output := unit
