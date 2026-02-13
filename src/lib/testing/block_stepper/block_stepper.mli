open Core
open Async
open Signature_lib
open Mina_base
open Mina_state

val create_genesis_breadcrumb :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> unit
  -> Frontier_base.Breadcrumb.t Deferred.t

type t

type start_state

val start_state_of_genesis : Frontier_base.Breadcrumb.t -> start_state

val start_state_of_breadcrumb :
     Frontier_base.Breadcrumb.t
  -> protocol_states:Protocol_state.value State_hash.Map.t
  -> start_state

val current_block : t -> Frontier_base.Breadcrumb.t

val remaining_slots : t -> int

val precomputed_values : t -> Precomputed_values.t

val verifier : t -> Verifier.t

val create :
     precomputed_values:Precomputed_values.t
  -> keypair:Keypair.t
  -> start:start_state
  -> logger:Logger.t
  -> ?n_slots:int
  -> unit
  -> t Deferred.t

val step :
     t
  -> transactions:User_command.Valid.t Sequence.t
  -> (Frontier_base.Breadcrumb.t * t) Deferred.t
