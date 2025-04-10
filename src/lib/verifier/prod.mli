include Verifier_intf.S with type ledger_proof = Ledger_proof.Prod.t

open Async_kernel
open Mina_base

module With_id_tag : sig
  type 'a t = int * 'a
end

module Worker_state : sig
  type t

  type init_arg =
    { conf_dir : string option
    ; enable_internal_tracing : bool
    ; internal_trace_filename : string option
    ; logger : Logger.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; commit_id : string
    ; blockchain_verification_key : Pickles.Verification_key.Stable.Latest.t
    ; transaction_verification_key : Pickles.Verification_key.Stable.Latest.t
    }

  val verify_commands :
       t
    -> Mina_base.User_command.Verifiable.t With_status.t With_id_tag.t list
    -> [ `Valid
       | `Valid_assuming of
         ( Pickles.Side_loaded.Verification_key.t
         * Mina_base.Zkapp_statement.t
         * Pickles.Side_loaded.Proof.t )
         list
       | invalid ]
       With_id_tag.t
       list
       Deferred.t

  val create : init_arg -> t Deferred.t
end
