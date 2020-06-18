open Core_kernel
open Coda_base
open Snark_params.Tick

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'token_id t = {next_available_token: 'token_id}
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'token_id t = 'token_id Stable.Latest.t =
    {next_available_token: 'token_id}
  [@@deriving sexp, eq, compare, fields, yojson]

  let to_hlist {next_available_token} = H_list.[next_available_token]

  let of_hlist ([next_available_token] : (unit, _) H_list.t) =
    {next_available_token}
end

type 'token_id poly = 'token_id Poly.t = {next_available_token: 'token_id}
[@@deriving sexp, eq, compare, fields, hash, yojson]

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Token_id.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t
end

type t = Value.t

type var = Token_id.var Poly.t

let typ : (var, t) Typ.t =
  Typ.of_hlistable [Token_id.typ] ~var_to_hlist:Poly.to_hlist
    ~var_of_hlist:Poly.of_hlist ~value_to_hlist:Poly.to_hlist
    ~value_of_hlist:Poly.of_hlist

let create_value ~next_available_token = {next_available_token}

let to_input ({next_available_token} : Value.t) =
  Token_id.to_input next_available_token

let var_to_input ({next_available_token} : var) =
  Token_id.Checked.to_input next_available_token
