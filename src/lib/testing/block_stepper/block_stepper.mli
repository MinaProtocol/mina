open Core
open Async
open Signature_lib
open Mina_base

val create_genesis_breadcrumb :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> unit
  -> Frontier_base.Breadcrumb.t Deferred.t

type t

val current_block : t -> Frontier_base.Breadcrumb.t

val remaining_slots : t -> int

val precomputed_values : t -> Precomputed_values.t

val verifier : t -> Verifier.t

val create :
     precomputed_values:Precomputed_values.t
  -> keypair:Keypair.t
  -> start_block:Frontier_base.Breadcrumb.t
  -> logger:Logger.t
  -> ?n_slots:int
  -> unit
  -> t Deferred.t

val step :
     t
  -> transactions:User_command.Valid.t Sequence.t
  -> (Frontier_base.Breadcrumb.t * t) Deferred.t
