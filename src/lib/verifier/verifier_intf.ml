open Async_kernel
open Core_kernel

module Base = struct
  module type S = sig
    type t

    type ledger_proof

    type invalid =
      [ `Invalid_keys of Signature_lib.Public_key.Compressed.t list
      | `Invalid_signature of Signature_lib.Public_key.Compressed.t list
      | `Invalid_proof of Error.t
      | `Missing_verification_key of Signature_lib.Public_key.Compressed.t list
      | `Unexpected_verification_key of
        Signature_lib.Public_key.Compressed.t list
      | `Mismatched_authorization_kind of
        Signature_lib.Public_key.Compressed.t list ]
    [@@deriving bin_io, to_yojson]

    val invalid_to_error : invalid -> Error.t

    val verify_commands :
         t
      -> Mina_base.User_command.Verifiable.t Mina_base.With_status.t list
         (* The first level of error represents failure to verify, the second a failure in
            communicating with the verifier. *)
      -> [ `Valid of Mina_base.User_command.Valid.t
         | `Valid_assuming of
           ( Pickles.Side_loaded.Verification_key.t
           * Mina_base.Zkapp_statement.t
           * Pickles.Side_loaded.Proof.t )
           list
         | invalid ]
         list
         Deferred.Or_error.t

    val verify_blockchain_snarks :
         t
      -> Blockchain_snark.Blockchain.t list
      -> unit Or_error.t Or_error.t Deferred.t

    val verify_transaction_snarks :
         t
      -> (ledger_proof * Mina_base.Sok_message.t) list
      -> unit Or_error.t Or_error.t Deferred.t

    val get_blockchain_verification_key :
      t -> Pickles.Verification_key.t Or_error.t Deferred.t

    val toggle_internal_tracing : t -> bool -> unit Or_error.t Deferred.t
  end
end

module type S = sig
  include Base.S

  val create :
       logger:Logger.t
    -> ?enable_internal_tracing:bool
    -> ?internal_trace_filename:string
    -> proof_level:Genesis_constants.Proof_level.t
    -> constraint_constants:Genesis_constants.Constraint_constants.t
    -> pids:Child_processes.Termination.t
    -> conf_dir:string option
    -> unit
    -> t Deferred.t
end
