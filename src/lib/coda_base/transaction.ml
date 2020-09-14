open Core

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'command t =
        | Command of 'command
        | Fee_transfer of Fee_transfer.Stable.V1.t
        | Coinbase of Coinbase.Stable.V1.t
      [@@deriving sexp, compare, eq, hash, yojson]

      let to_latest = Fn.id
    end
  end]
end

module Valid = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Command_transaction.Valid.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, compare, eq, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  include Hashable.Make (Stable.Latest)
  include Comparable.Make (Stable.Latest)
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Command_transaction.Stable.V1.t Poly.Stable.V1.t
    [@@deriving sexp, compare, eq, hash, yojson]

    let to_latest = Fn.id
  end
end]

include Hashable.Make (Stable.Latest)
include Comparable.Make (Stable.Latest)

type 'command t_ = 'command Poly.t =
  | Command of 'command
  | Fee_transfer of Fee_transfer.t
  | Coinbase of Coinbase.t

let forget : Valid.t -> t = fun x -> (x :> t)

let fee_excess : t -> Fee_excess.t Or_error.t = function
  | Command (User_command t) ->
      Ok (Signed_command.fee_excess t)
  | Command (Snapp_command t) ->
      Snapp_command.(fee_excess (t :> t))
  | Fee_transfer t ->
      Fee_transfer.fee_excess t
  | Coinbase t ->
      Coinbase.fee_excess t

let supply_increase = function
  | Command _ | Fee_transfer _ ->
      Ok Currency.Amount.zero
  | Coinbase t ->
      Coinbase.supply_increase t

let accounts_accessed ~next_available_token : t -> _ = function
  | Command (User_command cmd) ->
      Signed_command.accounts_accessed ~next_available_token cmd
  | Command (Snapp_command t) ->
      Snapp_command.(accounts_accessed (t :> t))
  | Fee_transfer ft ->
      Fee_transfer.receivers ft
  | Coinbase cb ->
      Coinbase.accounts_accessed cb

let next_available_token (t : t) next_available_token =
  match t with
  | Command (User_command cmd) ->
      Signed_command.next_available_token cmd next_available_token
  | Command (Snapp_command t) ->
      Snapp_command.next_available_token t next_available_token
  | Fee_transfer _ ->
      next_available_token
  | Coinbase _ ->
      next_available_token
