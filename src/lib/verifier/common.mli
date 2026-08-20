(** Core verification logic for user commands.

    This module provides the verification functions used both by the verifier
    subprocess and directly by other components. *)

open Core_kernel
open Mina_base

(** Verification failure reasons.
    Each variant includes the public keys of affected accounts. *)
type invalid =
  [ `Invalid_keys of Signature_lib.Public_key.Compressed.t list
    (** Public key failed decompression. *)
  | `Invalid_signature of Signature_lib.Public_key.Compressed.t list
    (** Schnorr signature verification failed. *)
  | `Invalid_proof of Error.t  (** Proof verification failed. *)
  | `Missing_verification_key of Signature_lib.Public_key.Compressed.t list
    (** zkApp account has proof authorization but no verification key. *)
  | `Unexpected_verification_key of Signature_lib.Public_key.Compressed.t list
    (** Verification key hash doesn't match expected hash in authorization. *)
  | `Mismatched_authorization_kind of Signature_lib.Public_key.Compressed.t list
    (** Authorization type (Signature/Proof/None_given) doesn't match
        [authorization_kind] field in account update body. *)
  ]
[@@deriving to_yojson]

(** {2 Bin_prot serialization for [invalid]}

    Manually exposed as [bin_io_unversioned] cannot be used in signatures. *)

val bin_size_invalid : invalid Bin_prot.Size.sizer

val bin_write_invalid : invalid Bin_prot.Write.writer

val bin_read_invalid : invalid Bin_prot.Read.reader

val __bin_read_invalid__ : (int -> invalid) Bin_prot.Read.reader

val bin_shape_invalid : Bin_prot.Shape.t

val bin_invalid : invalid Bin_prot.Type_class.t

(** Convert an [invalid] to a human-readable error. *)
val invalid_to_error : invalid -> Error.t

(** {2 Polymorphic verifiable command types}

    These types abstract over the proof and auxiliary data types to support
    both [User_command.Verifiable.t] (in-process) and
    [User_command.Verifiable.Serializable.t] (cross-process via RPC). *)

(** A zkApp command with verification key data attached.

    {b Type parameters:}
    - ['proof] is the proof type in account update authorizations
    - ['aux] is auxiliary data attached to account updates *)
type ('proof, 'aux) verifiable_zkapp_command =
  ( ( Account_update.Body.t
    , ('proof, Signature_lib.Schnorr.Chunked.Signature.t) Control.Poly.t
    , 'aux )
    Account_update.Poly.t
  , Verification_key_wire.t option )
  Zkapp_command.Call_forest.With_hashes_and_data.t
  Zkapp_command.Poly.t

(** A user command (signed or zkApp) in verifiable form.

    {b Type parameters:}
    - ['proof] is [Proof_cache_tag.t] for [User_command.Verifiable.t]
      or [Pickles.Side_loaded.Proof.t] for [User_command.Verifiable.Serializable.t]
    - ['aux] is [Account_update.T.Aux_data.t] for [User_command.Verifiable.t]
      or [unit] for [User_command.Verifiable.Serializable.t] *)
type ('proof, 'aux) verifiable_user_command =
  ( Signed_command.t
  , ('proof, 'aux) verifiable_zkapp_command )
  User_command.Poly.t

(** Verify a signed command's signature.

    @return [Ok (`Assuming [])] if valid, [Error invalid] otherwise *)
val check_signed_command :
     signature_kind:Mina_signature_kind.t
  -> Signed_command.t
  -> ([ `Assuming of 'a list ], invalid) Result.t

(** Collect verification key assumptions for zkApp proofs.

    For each account update with proof authorization, collects the
    (verification_key, statement, proof) tuple needed for async verification.

    The return error type is open [[>]] to allow callers to extend with
    additional error variants.

    @return [Error invalid] if verification key is missing or mismatched *)
val collect_vk_assumptions :
     ('proof, _) verifiable_zkapp_command
  -> ( (Side_loaded_verification_key.t * Zkapp_statement.t * 'proof) list
     , [> `Missing_verification_key of
          Signature_lib.Public_key.Compressed.t list
       | `Unexpected_verification_key of
         Signature_lib.Public_key.Compressed.t list ] )
     Result.t

(** Verify all signatures in a zkApp command.

    {2 Verification Flow}

    1. Compute transaction commitment from account updates
    2. Compute full commitment (includes memo and fee payer)
    3. Verify fee payer signature against full commitment
    4. For each account update with signature authorization:
       - Use full or partial commitment based on [use_full_commitment]
       - Verify signature against [body.public_key]

    This mirrors the logic enforced by the transaction SNARK
    (see [Transaction_snark.check_authorization]).

    @param signature_kind [Testnet] or [Mainnet] for domain separation *)
val check_signatures_of_zkapp_command :
     signature_kind:Mina_signature_kind.t
  -> Zkapp_command.t
  -> (unit, invalid) Result.t

(** Verify a user command (signed command or zkApp command).

    For signed commands: verifies the signature.
    For zkApp commands: verifies all signatures and collects proof assumptions.

    @return [Ok (`Assuming proofs)] where [proofs] is empty for signed commands
            or contains (vk, stmt, proof) tuples for zkApp proofs needing
            async verification *)
val check :
     signature_kind:Mina_signature_kind.t
  -> ('proof, 'aux) verifiable_user_command With_status.t
  -> ( [ `Assuming of
         (Side_loaded_verification_key.t * Zkapp_statement.t * 'proof) list ]
     , invalid )
     Result.t

(** Verify a command from the mempool, returning a valid command or error.

    Commands are considered valid if:
    - Failed status (already marked as failed)
    - Signed command (signature verified elsewhere)
    - zkApp command passing [collect_vk_assumptions] check

    {b Type parameters:}
    - Takes [User_command.Verifiable.t] which uses [Proof_cache_tag.t] internally
    - Returns open variant [[>]] to allow composition with [`No_fast_forward]
      in [Check_commands.verify_command_with_transaction_pool_proxy] *)
val verify_command_from_mempool :
     User_command.Verifiable.t With_status.t
  -> [> `Valid of User_command.Valid.t
     | `Missing_verification_key of Signature_lib.Public_key.Compressed.t list
     | `Unexpected_verification_key of
       Signature_lib.Public_key.Compressed.t list ]
