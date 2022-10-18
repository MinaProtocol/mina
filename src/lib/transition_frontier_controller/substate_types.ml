open Mina_base
open Core_kernel
open Async_kernel

(** Context for a transition that is being processed.

    Parameter ['a] denotes the result of deferred action associated
    with the transition's state.    
*)
type 'a processing_context =
  | In_progress of { interrupt_ivar : unit Ivar.t; timeout : Time.t }
      (** A deferred action is in progress *)
  | Dependent
      (** A deferred action is to be handled by a gossiped descedant
      (so that this transition is part of the descedant's batch) *)
  | Done of 'a
      (** A deferred action is complete. This constructor is used only as
      a transient marker before making the transition processed right after. *)

(** Status of the transition.

    Status is local within the given state. Each transition passes
    through each state before eventually being added to frontier,
    status is updated a few times until it's equal to [Processed].

    Transition in [Processed] status can be transitioned to the next
    state.

    Parameter ['a] denotes the result of deferred action associated
    with the transition state.    
     *)
type 'a status =
  | Waiting_for_parent of (unit -> 'a status)
  (*** Waiting for parent to be processed before starting the processing.
     This state might be skipped when sequential processing is unnecessary. *)
  | Processing of 'a processing_context
      (** Processing of the state is in progress. *)
  | Failed of Error.t  (** Processing failed, but could be retried *)
  | Processed of 'a
      (** State is processed and ready to be transitioned to higher state after
     ancestry is also processed *)

(** Container for children of a transition.

    Children are separated based on their status into three
    non-intersecting sets. *)
type children_sets =
  { processed : State_hash.Set.t
  ; waiting_for_parent : State_hash.Set.t
  ; processing_or_failed : State_hash.Set.t
  }

let empty_children_sets =
  { processing_or_failed = State_hash.Set.empty
  ; processed = State_hash.Set.empty
  ; waiting_for_parent = State_hash.Set.empty
  }

(** Type ['a t] represents the common substate of most states
    through which transition passes while being in catchup state.
    
    Parameter ['a] denotes the result of deferred action associated
    with the transition state. See [status] type's documentation.  

    The common substate notion allows a unified logic of data
    dependency management for all the transition states. *)
type 'a t = { status : 'a status; children : children_sets }

(** Wrapper for a function that modifies ['a t] stored in a
    transition's state.
    
    Modifier changes the common substate and
    returns an auxiliary data ['v] that can be used in later
    computation. *)
type 'v modifier = { modifier : 'a. 'a t -> 'a t * 'v }

(** Wrapper for a function that views ['a t] stored in
    a transition's state.
    
    Viewer takes common substate and returns some value ['v]. 
    *)
type 'v viewer = { viewer : 'a. 'a t -> 'v }

(** Metadata of a transition.

    Contains minimal information for the transition to
    be kept in catchup state and later evicted from it.    
*)
type transition_meta =
  { state_hash : State_hash.t
  ; blockchain_length : Mina_numbers.Length.t
  ; parent_state_hash : State_hash.t
  }

(** Functions to work with the transition state being
    treated as an abstract type *)
module type State_functions = sig
  (** Abstract type for transition's state  *)
  type state_t

  (** Function that takes a common substate [modifier] and applies it
      to the transition state, returning new transition state and an
      auxiliary data (specified by modifier).
  *)
  val modify_substate : f:'a modifier -> state_t -> (state_t * 'a) option

  (** Function that extracts [transition_meta] out of [state_t]  *)
  val transition_meta : state_t -> transition_meta

  (** Function that returns whether two states are on "same level".
      
      "Same level" means that they are on the same logical state, but corresponding
      to different transitions they are not equal as values (and may have different
      statuses).
  *)
  val equal_state_levels : state_t -> state_t -> bool
end

let transition_meta_of_header_with_hash hh =
  let h = With_hash.data hh in
  { state_hash = State_hash.With_state_hashes.state_hash hh
  ; parent_state_hash =
      Mina_state.Protocol_state.previous_state_hash
      @@ Mina_block.Header.protocol_state h
  ; blockchain_length = Mina_block.Header.blockchain_length h
  }
