module type S = sig
  module Error : sig
    type t =
      | Verification_failed of Verifier.Failure.t
      | Coinbase_error of string
      | Insufficient_fee of Currency.Fee.t * Currency.Fee.t
      | Internal_command_status_mismatch
      | Unexpected of Error.t
    [@@deriving sexp]

    val to_string : t -> string

    val to_error : t -> Error.t
  end

  val get_unchecked :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> coinbase_receiver:Signature_lib.Public_key.Compressed.t
    -> supercharge_coinbase:bool
    -> Staged_ledger_diff.With_valid_signatures_and_proofs.t
    -> ( Mina_transaction.Transaction.Valid.t Mina_base.With_status.t list
         * Transaction_snark_work.t list
         * int
         * Currency.Amount.t list
       , Error.t )
       result

  val get_transactions :
       constraint_constants:Genesis_constants.Constraint_constants.t
    -> coinbase_receiver:Signature_lib.Public_key.Compressed.t
    -> supercharge_coinbase:bool
    -> Staged_ledger_diff.t
    -> ( Mina_transaction.Transaction.t Mina_base.With_status.t list
       , Error.t )
       result
end
