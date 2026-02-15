open Core
open Async
open Signature_lib
open Mina_base

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

val current_block : t -> Frontier_base.Breadcrumb.t

val precomputed_values : t -> Precomputed_values.t

val create_from_genesis :
     precomputed_values:Precomputed_values.t
  -> keypair:Keypair.t
  -> keys_module:(module Keys_S)
  -> logger:Logger.t
  -> state_dir:string
  -> ?parallel_workers:int
  -> unit
  -> t Deferred.Or_error.t

val step :
     t
  -> transactions:User_command.Valid.t Sequence.t
  -> (Frontier_base.Breadcrumb.t * t) Deferred.Or_error.t
