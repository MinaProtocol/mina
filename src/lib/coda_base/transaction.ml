open Core

(* TODO : version *)
type fee_transfer = Fee_transfer.Stable.V1.t [@@deriving bin_io, sexp]

module Stable = struct
  module Latest = struct
    type t =
      | User_command of User_command.With_valid_signature.Stable.Latest.t
      | Fee_transfer of Fee_transfer.Stable.Latest.t
      | Coinbase of Coinbase.Stable.Latest.t
    [@@deriving sexp, bin_io, compare, eq]
  end

  module V1 = struct
    module T = struct
      type t =
        | User_command of User_command.With_valid_signature.Stable.V1.t
        | Fee_transfer of Fee_transfer.Stable.V1.t
        | Coinbase of Coinbase.Stable.V1.t
      [@@deriving bin_io, sexp, version, compare, eq]
    end

    include T

    let to_latest : t -> Latest.t = function
      | User_command command -> User_command command
      | Fee_transfer fee_transfer -> Fee_transfer fee_transfer
      | Coinbase coinbase -> Coinbase coinbase
  end
end

type t = Stable.Latest.t =
  | User_command of User_command.With_valid_signature.Stable.Latest.t
  | Fee_transfer of Fee_transfer.Stable.Latest.t
  | Coinbase of Coinbase.Stable.Latest.t
[@@deriving sexp, compare, eq]

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
