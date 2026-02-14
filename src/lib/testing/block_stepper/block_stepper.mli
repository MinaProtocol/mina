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

module type Keys_S = sig
  module T : Transaction_snark.S

  module B : Blockchain_snark.Blockchain_snark_state.S
end

module Keys (Params : sig
  val signature_kind : Mina_signature_kind.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : Keys_S

type t

type start_state

val start_state_of_genesis :
  Frontier_base.Breadcrumb.t -> keys_module:(module Keys_S) -> start_state

val start_state_of_breadcrumb :
     Frontier_base.Breadcrumb.t
  -> protocol_states:Protocol_state.value State_hash.Map.t
  -> keys_module:(module Keys_S)
  -> start_state

val current_block : t -> Frontier_base.Breadcrumb.t

val precomputed_values : t -> Precomputed_values.t

val create :
     precomputed_values:Precomputed_values.t
  -> keypair:Keypair.t
  -> start:start_state
  -> logger:Logger.t
  -> state_dir:string
  -> unit
  -> t Deferred.t

val step :
     t
  -> transactions:User_command.Valid.t Sequence.t
  -> (Frontier_base.Breadcrumb.t * t) Deferred.t
