open Core_kernel
open Snark_params.Tick
open Signature_lib
module Amount = Currency.Amount

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('public_key, 'amount, 'bool) t =
        {receiver_pk: 'public_key; amount: 'amount; whitelist: 'bool}
      [@@deriving eq, sexp, hash, yojson, compare]
    end
  end]

  type ('public_key, 'amount, 'bool) t =
        ('public_key, 'amount, 'bool) Stable.Latest.t =
    {receiver_pk: 'public_key; amount: 'amount; whitelist: 'bool}
  [@@deriving eq, sexp, hash, yojson, compare]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Amount.Stable.V1.t
      , bool )
      Poly.Stable.V1.t
    [@@deriving compare, eq, sexp, hash, compare, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

type var = (Public_key.Compressed.var, Amount.var, Boolean.var) Poly.t

let typ : (var, t) Typ.t =
  let spec =
    let open Data_spec in
    [Public_key.Compressed.typ; Amount.typ; Boolean.typ]
  in
  let of_hlist
        : 'a 'b 'c.    (unit, 'a -> 'b -> 'c -> unit) H_list.t
          -> ('a, 'b, 'c) Poly.t =
    let open H_list in
    fun [receiver_pk; amount; whitelist] -> {receiver_pk; amount; whitelist}
  in
  let to_hlist Poly.{receiver_pk; amount; whitelist} =
    H_list.[receiver_pk; amount; whitelist]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let to_input {Poly.receiver_pk; amount; whitelist} =
  Random_oracle.Input.(
    append (Public_key.Compressed.to_input receiver_pk)
    @@ append (bitstring (Amount.to_bits amount)) (bitstring [whitelist]))

let var_to_input {Poly.receiver_pk; amount; whitelist} =
  Random_oracle.Input.(
    append (Public_key.Compressed.Checked.to_input receiver_pk)
    @@ append
         (bitstring
            (Bitstring_lib.Bitstring.Lsb_first.to_list
               (Amount.var_to_bits amount)))
         (bitstring [whitelist]))

let var_of_t {Poly.receiver_pk; amount; whitelist} =
  { Poly.receiver_pk= Public_key.Compressed.var_of_t receiver_pk
  ; amount= Amount.var_of_t amount
  ; whitelist= Boolean.var_of_value whitelist }

let gen ~max_amount ~whitelist =
  let open Quickcheck.Generator.Let_syntax in
  let%map receiver_pk = Public_key.Compressed.gen
  and amount = Amount.gen_incl Amount.zero max_amount in
  Poly.{receiver_pk; amount; whitelist}
