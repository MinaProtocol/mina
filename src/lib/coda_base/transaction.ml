open Core

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

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

let fee_excess : t -> Fee_excess.t Or_error.t = function
  | User_command t ->
      Ok (User_command.fee_excess (User_command.forget_check t))
  | Fee_transfer t ->
      Fee_transfer.fee_excess t
  | Coinbase t ->
      Coinbase.fee_excess t

let supply_increase = function
  | User_command _ | Fee_transfer _ ->
      Ok Currency.Amount.zero
  | Coinbase t ->
      Coinbase.supply_increase t

let accounts_accessed ~next_available_token = function
  | User_command cmd ->
      User_command.accounts_accessed ~next_available_token
        (User_command.forget_check cmd)
  | Fee_transfer ft ->
      Fee_transfer.receivers ft
  | Coinbase cb ->
      Coinbase.accounts_accessed cb

let next_available_token t next_available_token =
  match t with
  | User_command cmd ->
      User_command.next_available_token
        (User_command.forget_check cmd)
        next_available_token
  | Fee_transfer _ ->
      next_available_token
  | Coinbase _ ->
      next_available_token
