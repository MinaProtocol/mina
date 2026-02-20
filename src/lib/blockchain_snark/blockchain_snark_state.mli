(** Blockchain SNARK circuits.

    This code is called in:
    - [src/lib/prover/prover.ml] - block production
    - [src/lib/verifier/verifier.ml] - proof verification
    - [src/lib/genesis_proof/genesis_proof.ml] - genesis proof

    The blockchain SNARK has 1 circuit:

    - {b blockchain-step}: Proves a single step of the blockchain state
      transition. Each step verifies that the protocol state was correctly
      updated from the previous state by applying a valid block (including
      its transaction snark proof).

    Constraint counts vary by profile due to different configuration parameters
    (e.g., ledger depth).

    Note: These values are measured with proof_level=Full, which generates the
    actual constraint system used in production. See {!Genesis_constants.Proof_level}
    for details on proof levels.

    {b Dev profile:}
    {v
    | Circuit         | Constraints | Public Input | Auxiliary Input |
    |-----------------|-------------|--------------|-----------------|
    | blockchain-step | 9,168       | 1            | 31,925          |
    v}

    {b Devnet profile:}
    {v
    | Circuit         | Constraints | Public Input | Auxiliary Input |
    |-----------------|-------------|--------------|-----------------|
    | blockchain-step | 10,224      | 1            | 39,397          |
    v}

    {b Lightnet profile:}
    {v
    | Circuit         | Constraints | Public Input | Auxiliary Input |
    |-----------------|-------------|--------------|-----------------|
    | blockchain-step | 10,126      | 1            | 38,359          |
    v}

    {b Mainnet profile:}
    {v
    | Circuit         | Constraints | Public Input | Auxiliary Input |
    |-----------------|-------------|--------------|-----------------|
    | blockchain-step | 10,224      | 1            | 39,397          |
    v}

    If these values change, update the tables above and the expected values in
    [tests/test_blockchain_snark.ml]. *)

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

(** Return the constraint system for the blockchain-step circuit. *)
val step_constraint_system :
     proof_level:Genesis_constants.Proof_level.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> Snark_params.Tick.R1CS_constraint_system.t

val constraint_system_digests :
     proof_level:Genesis_constants.Proof_level.t
  -> constraint_constants:Genesis_constants.Constraint_constants.t
  -> unit
  -> (string * Md5.t) list
