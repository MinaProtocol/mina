open Core

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | User_command of User_command.With_valid_signature.Stable.V1.t
      | Fee_transfer of Fee_transfer.Stable.V1.t
      | Coinbase of Coinbase.Stable.V1.t
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id
  end
end]

module T = struct
  module T0 = struct
    type t = Stable.Latest.t =
      | User_command of User_command.With_valid_signature.t
      | Fee_transfer of Fee_transfer.t
      | Coinbase of Coinbase.t
    [@@deriving sexp, compare, eq, hash, yojson]
  end

  include Hashable.Make (T0)
  include Comparable.Make (T0)
  include T0
end

include T

let fee_excess = function
  | User_command t ->
      Ok
        (Currency.Fee.Signed.of_unsigned
           (User_command_payload.fee (t :> User_command.t).payload))
  | Fee_transfer t ->
      Fee_transfer.fee_excess t
  | Coinbase t ->
      Coinbase.fee_excess t

let fee_token = function
  | User_command t ->
      User_command_payload.fee_token (User_command.forget_check t).payload
  | Fee_transfer t ->
      Fee_transfer.fee_token t
  | Coinbase _t ->
      Token_id.default

(* NB: This should match the implementation in [Transaction_union]. *)
let fee_excess_l (t : t) =
  Or_error.map (fee_excess t) ~f:(fun fee_excess ->
      if Currency.Fee.Signed.(equal zero) fee_excess then
        (Token_id.default, fee_excess)
      else (fee_token t, fee_excess) )

(* NB: This should match the implementation in [Transaction_union]. *)
let fee_excess_r (_ : t) = Ok (Token_id.default, Currency.Fee.Signed.zero)

let supply_increase = function
  | User_command _ | Fee_transfer _ ->
      Ok Currency.Amount.zero
  | Coinbase t ->
      Coinbase.supply_increase t
