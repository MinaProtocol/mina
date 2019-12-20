open Core
open Snark_params.Tick
open Import

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('pk, 'amount) t = {receiver: 'pk; amount: 'amount}
      [@@deriving eq, sexp, hash, yojson]
    end
  end]

  type ('pk, 'amount) t = ('pk, 'amount) Stable.Latest.t =
    {receiver: 'pk; amount: 'amount}
  [@@deriving eq, sexp, hash, yojson]
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Currency.Amount.Stable.V1.t )
      Poly.Stable.V1.t
    [@@deriving bin_io, compare, eq, sexp, hash, yojson, version]
  end
end]

type t = Stable.Latest.t
  constraint t = (Public_key.Compressed.t, Currency.Amount.t) Poly.t
[@@deriving eq, sexp, hash, yojson]

val dummy : t

val gen : max_amount:Currency.Amount.t -> t Quickcheck.Generator.t

type var = (Public_key.Compressed.var, Currency.Amount.var) Poly.t

val typ : (var, t) Typ.t

val to_input : t -> (Field.t, bool) Random_oracle.Input.t

val var_to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t

val var_of_t : t -> var
