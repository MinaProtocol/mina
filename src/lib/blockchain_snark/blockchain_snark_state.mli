open Mina_base
open Mina_state
open Core_kernel
open Pickles_types

module Witness : sig
  type t =
    { prev_state : Protocol_state.Value.t
    ; prev_state_proof : Nat.N2.n Pickles.Proof.t
    ; transition : Snark_transition.Value.t
    ; txn_snark : Transaction_snark.Statement.With_sok.t
    ; txn_snark_proof : Nat.N2.n Pickles.Proof.t
    }
end

type tag =
  ( Protocol_state.value Data_as_hash.t
  , Protocol_state.value
  , Nat.N2.n
  , Nat.N1.n )
  Pickles.Tag.t

val verify :
     (Protocol_state.Value.t * Proof.t) list
  -> key:Pickles.Verification_key.t
  -> unit Or_error.t Async.Deferred.t

val check :
     Witness.t
  -> ?handler:
       (   Snarky_backendless.Request.request
        -> Snarky_backendless.Request.response )
  -> proof_level:Genesis_constants.Proof_level.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> Protocol_state.value
  -> unit Or_error.t

module type S = sig
  module Proof :
    Pickles.Proof_intf
      with type t = Nat.N2.n Pickles.Proof.t
       and type statement = Protocol_state.Value.t

  val tag : tag

  val cache_handle : Pickles.Cache_handle.t

  open Nat

  val step :
       Witness.t
    -> ( Protocol_state.Value.t * (Transaction_snark.Statement.With_sok.t * unit)
       , N2.n * (N2.n * unit)
       , N1.n * (N5.n * unit)
       , Protocol_state.Value.t
       , (unit * unit * Proof.t) Async.Deferred.t )
       Pickles.Prover.t

  val constraint_system_digests : (string * Md5_lib.t) list Lazy.t
end

module Make (T : sig
  val tag : Transaction_snark.tag

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : S
[@@warning "-67"]

val constraint_system_digests :
     proof_level:Genesis_constants.Proof_level.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> unit
  -> (string * Md5.t) list
