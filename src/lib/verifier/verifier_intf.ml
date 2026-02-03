(** Verifier module type signatures.

    Defines the interface for transaction and SNARK verification. Two module
    types are provided:

    - [Base.S]: Core verification operations (used by components that receive
      an already-created verifier)
    - [S]: Extends [Base.S] with [create] (used by [Mina_lib] to instantiate
      the verifier)

    Implementations: [Prod] (separate process) and [Dummy] (no-op for tests). *)

open Async_kernel
open Core_kernel

(** Base verifier interface without creation. *)
module Base = struct
  module type S = sig
    type t
    (** The verifier instance. *)

    type ledger_proof
    (** Ledger proof type (transaction SNARK). *)

    (** Verification failure reasons.
        Each variant includes the public keys of affected accounts. *)
    type invalid =
      [ `Invalid_keys of Signature_lib.Public_key.Compressed.t list
        (** Public key failed validity check. *)
      | `Invalid_signature of Signature_lib.Public_key.Compressed.t list
        (** Signature verification failed. *)
      | `Invalid_proof of Error.t
        (** Proof verification failed. *)
      | `Missing_verification_key of Signature_lib.Public_key.Compressed.t list
        (** zkApp account missing verification key for proof. *)
      | `Unexpected_verification_key of
        Signature_lib.Public_key.Compressed.t list
        (** Verification key hash mismatch. *)
      | `Mismatched_authorization_kind of
        Signature_lib.Public_key.Compressed.t list
        (** Authorization type doesn't match authorization_kind field. *) ]
    [@@deriving bin_io, to_yojson]

    val invalid_to_error : invalid -> Error.t

    (** Verify user commands (signed commands and zkApp commands).

        For each command, returns:
        - [`Valid cmd]: Command verified, includes validated command
        - [`Valid_assuming proofs]: Signatures valid, proofs need async verification
        - [invalid]: Verification failed *)
    val verify_commands :
         t
      -> Mina_base.User_command.Verifiable.t Mina_base.With_status.t list
      -> [ `Valid of Mina_base.User_command.Valid.t
         | `Valid_assuming of
           ( Pickles.Side_loaded.Verification_key.t
           * Mina_base.Zkapp_statement.t
           * Pickles.Side_loaded.Proof.t )
           list
         | invalid ]
         list
         Deferred.Or_error.t

    (** Verify blockchain SNARKs (protocol state transition proofs). *)
    val verify_blockchain_snarks :
         t
      -> Blockchain_snark.Blockchain.t list
      -> unit Or_error.t Or_error.t Deferred.t

    (** Verify transaction SNARKs (ledger transition proofs).

        @param proofs List of [(ledger_proof, sok_message)] pairs where:
        - [ledger_proof]: The transaction SNARK proving valid ledger transition
        - [sok_message]: "Statement of knowledge" containing the fee and prover's
          public key, ensuring the SNARK worker gets credited for their work *)
    val verify_transaction_snarks :
         t
      -> (ledger_proof * Mina_base.Sok_message.t) list
      -> unit Or_error.t Or_error.t Deferred.t

    (** Enable or disable internal tracing in the verifier process. *)
    val toggle_internal_tracing : t -> bool -> unit Or_error.t Deferred.t

    (** Configure ITN logger with daemon port and process kind. *)
    val set_itn_logger_data : t -> daemon_port:int -> unit Or_error.t Deferred.t
  end
end

(** Full verifier interface including creation. *)
module type S = sig
  include Base.S

  (** Create a verifier instance.

      Spawns a child process via [Rpc_parallel] (for [Prod] implementation).

      @param proof_level [Full] for real verification, [Check]/[No_check] for testing
      @param blockchain_verification_key Key for verifying blockchain SNARKs
      @param transaction_verification_key Key for verifying transaction SNARKs
      @param signature_kind [Testnet] or [Mainnet] for signature domain separation *)
  val create :
       logger:Logger.t
    -> ?enable_internal_tracing:bool
    -> ?internal_trace_filename:string
    -> proof_level:Genesis_constants.Proof_level.t
    -> pids:Child_processes.Termination.t
    -> conf_dir:string option
    -> commit_id:string
    -> blockchain_verification_key:Pickles.Verification_key.t
    -> transaction_verification_key:Pickles.Verification_key.t
    -> signature_kind:Mina_signature_kind.t
    -> unit
    -> t Deferred.t
end
