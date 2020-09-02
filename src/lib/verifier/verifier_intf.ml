open Async_kernel
open Core_kernel

module Base = struct
  module type S = sig
    type t

    type ledger_proof

    (* TODO: For the future, this interface is a bit coarse and could really stand to be optimized.
   It should return a pair of commands that are definitely invalid and a list of commands that are
   potentially invalid because they failed in a batch. *)
    val verify_commands :
         t
      -> Coda_base.Command_transaction.Verifiable.t list
         (* The first level of error represents failure to verify, the second a failure in
   communicating with the verifier. *)
      -> ( Coda_base.Command_transaction.Valid.t list
         , Verification_failure.t )
         Result.t
         Deferred.Or_error.t

    val verify_blockchain_snark :
      t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

    val verify_transaction_snarks :
         t
      -> (ledger_proof * Coda_base.Sok_message.t) list
      -> bool Or_error.t Deferred.t
  end
end

module type S = sig
  include Base.S

  val create :
       logger:Logger.t
    -> proof_level:Genesis_constants.Proof_level.t
    -> pids:Child_processes.Termination.t
    -> conf_dir:string option
    -> t Deferred.t
end
