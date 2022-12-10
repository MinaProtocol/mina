open Core_kernel
open Bit_catchup_state

(** Summary of the state relevant to verifying generic functions  *)
type 'a data = { substate : 'a Substate.t; baton : bool }

module type F = sig
  (** Result of processing *)
  type processing_result

  (** Resolve all gossips held in the state to [`Ignore] *)
  val ignore_gossip : Transition_state.t -> Transition_state.t

  (** Extract data from the state *)
  val to_data : Transition_state.t -> processing_result data option

  (** Update state witht the given data *)
  val update :
    processing_result data -> Transition_state.t -> Transition_state.t

  (** Name of data being verified, for logging  *)
  val data_name : string

  val split_to_batches :
       Transition_state.t Mina_stdlib.Nonempty_list.t
    -> Transition_state.t Mina_stdlib.Nonempty_list.t
       Mina_stdlib.Nonempty_list.t

  (** Launch processing and return the deferred action launched along
      with timeout.

    [states] parameter represents a list of transition and all of its
    ancestors that are neither in [Substate.Processed] status nor has an
    processing action already launched for it and its ancestors.

    Pre-condition: function takes non-empty list of states in parent-first order.
*)
  val verify :
       context:(module Context.CONTEXT)
    -> (module Interruptible.F)
    -> Transition_state.t Mina_stdlib.Nonempty_list.t
    -> ( processing_result list
       , [> `Invalid_proof of Error.t | `Verifier_error of Error.t ] )
       Result.t
       Interruptible.t
       * Time.Span.t
end
