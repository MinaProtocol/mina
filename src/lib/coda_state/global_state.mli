open Core_kernel
open Coda_base
open Snark_params.Tick

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'token_id t = {next_available_token: 'token_id}
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type 'token_id t = {next_available_token: 'token_id}
  [@@deriving sexp, eq, compare, fields, yojson]
end

type 'token_id poly = 'token_id Poly.t = {next_available_token: 'token_id}
[@@deriving sexp, eq, compare, fields, hash, yojson]

module Value : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Token_id.Stable.V1.t Poly.Stable.V1.t
      [@@deriving sexp, eq, compare, hash, yojson]
    end
  end]

  type t = Stable.Latest.t
end

type t = Value.t

type var = Token_id.var Poly.t

val typ : (var, t) Typ.t

val create_value : next_available_token:Token_id.t -> Value.t

val to_input : Value.t -> (Field.t, bool) Random_oracle.Input.t

val var_to_input :
  var -> ((Field.Var.t, Boolean.var) Random_oracle.Input.t, _) Checked.t
