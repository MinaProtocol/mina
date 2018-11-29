open Coda_base
open Signature_lib

(* The goal of the executor is to get a sequence of transactions executed.
   To do so, it may need to periodically bump the fee. *)

module type S = sig
  type t

  val create :
       account_nonce:Account.Nonce.t
    -> broadcast:(User_command.Payload.t -> unit)
    -> t

  val payout :
    t -> receiver:Public_key.Compressed.t -> amount:Currency.Amount.t -> unit

  val long_tip_confirm :
    t -> account_nonce:Account.Nonce.t -> length:Coda_numbers.Length.t -> unit

  val locked_tip_confirm :
       t
    -> account_nonce:Account.Nonce.t
    -> Currency.Amount.t Public_key.Compressed.Table.t
end
