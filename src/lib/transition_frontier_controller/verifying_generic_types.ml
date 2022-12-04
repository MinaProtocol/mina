open Core_kernel
open Mina_base
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

  (** Launch processing and return the processing context
    along with the deferred action launched.

    [states] parameter represents a list of transition and all of its
    ancestors that are neither in [Substate.Processed] status nor has an
    processing action already launched for it and its ancestors.

    Pre-condition: function takes non-empty list of states in child-first order.
*)
  val create_in_progress_context :
       context:(module Context.CONTEXT)
    -> holder:State_hash.t ref
    -> Transition_state.t Mina_stdlib.Nonempty_list.t
    -> processing_result Substate.processing_context
       * ( ( processing_result list
           , [ `Invalid_proof of Error.t | `Verifier_error of Error.t ] )
           Result.t
         , unit )
         Async_kernel.Deferred.Result.t

  val data_name : string
end
