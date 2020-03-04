open Core_kernel
open Snark_params.Tick

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('public_key, 'amount, 'bool) t =
        { receiver_pk: 'public_key
        ; amount: 'amount
        ; approved_accounts_only: 'bool }
      [@@deriving eq, sexp, hash, yojson, compare]
    end
  end]

  type ('public_key, 'amount, 'bool) t =
        ('public_key, 'amount, 'bool) Stable.Latest.t =
    {receiver_pk: 'public_key; amount: 'amount; approved_accounts_only: 'bool}
  [@@deriving eq, sexp, hash, yojson, compare]
end

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      ( Signature_lib.Public_key.Compressed.Stable.V1.t
      , Currency.Amount.Stable.V1.t
      , bool )
      Poly.Stable.V1.t
    [@@deriving compare, eq, sexp, hash, compare, yojson]
  end
end]

type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

val gen :
     max_amount:Currency.Amount.t
  -> approved_accounts_only:bool
  -> t Quickcheck.Generator.t

type var =
  ( Signature_lib.Public_key.Compressed.var
  , Currency.Amount.var
  , Boolean.var )
  Poly.t

val typ : (var, t) Typ.t

val to_input : t -> (Field.t, bool) Random_oracle.Input.t

val var_to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t

val var_of_t : t -> var
