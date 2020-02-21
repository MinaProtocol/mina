open Core

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      | User_command of User_command.With_valid_signature.Stable.V2.t
      | Fee_transfer of Fee_transfer.Stable.V1.t
      | Coinbase of Coinbase.Stable.V1.t
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t =
      | User_command of User_command.With_valid_signature.Stable.V1.t
      | Fee_transfer of Fee_transfer.Stable.V1.t
      | Coinbase of Coinbase.Stable.V1.t
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = function
      | User_command uc ->
          V2.User_command
            (User_command.With_valid_signature.Stable.V1.to_latest uc)
      | Fee_transfer ft ->
          Fee_transfer ft
      | Coinbase cb ->
          Coinbase cb

    let of_latest = function
      | V2.User_command uc ->
          Result.map (User_command.With_valid_signature.Stable.V1.of_latest uc)
            ~f:(fun uc -> User_command uc)
      | Fee_transfer ft ->
          Ok (Fee_transfer ft)
      | Coinbase cb ->
          Ok (Coinbase cb)
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

let supply_increase = function
  | User_command _ | Fee_transfer _ ->
      Ok Currency.Amount.zero
  | Coinbase t ->
      Coinbase.supply_increase t
