open Core

(* TODO : version *)
type fee_transfer = Fee_transfer.Stable.V1.t [@@deriving bin_io, sexp]

(* TODO : version *)
type t =
  | User_command of User_command.With_valid_signature.t
  | Fee_transfer of Fee_transfer.Stable.V1.t
  | Coinbase of Coinbase.Stable.V1.t
[@@deriving bin_io, compare, eq, sexp]

let fee_excess = function
  | User_command t ->
      Ok
        (Currency.Fee.Signed.of_unsigned
           (User_command_payload.fee (t :> User_command.t).payload))
  | Fee_transfer t -> Fee_transfer.fee_excess t
  | Coinbase t -> Coinbase.fee_excess t

let supply_increase = function
  | User_command _ | Fee_transfer _ -> Ok Currency.Amount.zero
  | Coinbase t -> Coinbase.supply_increase t
