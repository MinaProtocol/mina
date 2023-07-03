open Async_kernel
open Core_kernel
open Mina_base

type t = (State_hash.t * unit Ivar.t) option ref

let report_finalized (t : t) state_hash =
  Option.iter !t ~f:(fun (target, ivar) ->
      if State_hash.equal target state_hash then Ivar.fill_if_empty ivar () )

let wait_for_finalization (t : t) timeout_span state_hash =
  let ivar = Ivar.create () in
  t := Some (state_hash, ivar) ;
  let deferred =
    Deferred.choose
      [ Deferred.choice (Ivar.read ivar) (Fn.const `Transition_accepted)
      ; Deferred.choice (Async_kernel.after timeout_span) (Fn.const `Timed_out)
      ]
  in
  upon deferred (fun _ -> t := None) ;
  deferred

let create () : t = ref None
