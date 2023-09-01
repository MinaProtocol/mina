(** A cache containing precomputed proofs for a given public input and
    verification key.

    The proofs are encoded in Yojson format, to ensure that a change to
    serialization doesn't cause a hard failure of tests using the cache.
*)
type t

val empty : unit -> t

(** Perform a lookup on the raw cache. *)
val get_proof :
     t
  -> verification_key:Yojson.Safe.t
  -> public_input:Yojson.Safe.t
  -> Yojson.Safe.t option

(** Get a step proof from the cache for the given keypair and public input. *)
val get_step_proof :
     t
  -> keypair:Backend.Tick.Keypair.t
  -> public_input:Kimchi_bindings.FieldVectors.Fp.t
  -> Backend.Tick.Proof.t Option.t

(** Get a wrap proof from the cache for the given keypair and public input. *)
val get_wrap_proof :
     t
  -> keypair:Backend.Tock.Keypair.t
  -> public_input:Kimchi_bindings.FieldVectors.Fq.t
  -> Backend.Tock.Proof.t Option.t

(** Add a proof to the raw cache. *)
val set_proof :
     t
  -> verification_key:Yojson.Safe.t
  -> public_input:Yojson.Safe.t
  -> Yojson.Safe.t
  -> unit

(** Add a step proof to the cache for the given keypair and public input. *)
val set_step_proof :
     t
  -> keypair:Backend.Tick.Keypair.t
  -> public_input:Kimchi_bindings.FieldVectors.Fp.t
  -> Backend.Tick.Proof.t
  -> unit

(** Add a wrap proof to the cache for the given keypair and public input. *)
val set_wrap_proof :
     t
  -> keypair:Backend.Tock.Keypair.t
  -> public_input:Kimchi_bindings.FieldVectors.Fq.t
  -> Backend.Tock.Proof.t
  -> unit
