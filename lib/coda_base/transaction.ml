open Core
module Public_key = Signature_lib.Public_key
module Payment = Payment
module Fee_transfer = Fee_transfer
module Coinbase = Coinbase

type t =
  | Valid_payment of Payment.With_valid_signature.t
  | Fee_transfer of Fee_transfer.t
  | Coinbase of Coinbase.t
[@@deriving bin_io, eq, sexp]

let fee_excess = function
  | Valid_payment t ->
      Ok (Currency.Fee.Signed.of_unsigned (t :> Payment.t).payload.fee)
  | Fee_transfer t -> Fee_transfer.fee_excess t
  | Coinbase t -> Coinbase.fee_excess t

let supply_increase = function
  | Valid_payment _ | Fee_transfer _ -> Ok Currency.Amount.zero
  | Coinbase t -> Coinbase.supply_increase t
