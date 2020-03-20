(* payment_payload.ml *)

[%%import
"/src/config.mlh"]

open Core_kernel
open Import

[%%ifdef
consensus_mechanism]

open Snark_params.Tick

[%%else]

module Currency = Currency_nonconsensus.Currency

[%%endif]

module Amount = Currency.Amount
module Fee = Currency.Fee

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('pk, 'amount) t = {receiver: 'pk; amount: 'amount}
      [@@deriving eq, sexp, hash, yojson, compare]
    end
  end]

  type ('pk, 'amount) t = ('pk, 'amount) Stable.Latest.t =
    {receiver: 'pk; amount: 'amount}
  [@@deriving eq, sexp, hash, yojson, compare]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      (Public_key.Compressed.Stable.V1.t, Amount.Stable.V1.t) Poly.Stable.V1.t
    [@@deriving compare, eq, sexp, hash, compare, yojson]

    let to_latest = Fn.id
  end
end]

type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

let dummy = Poly.{receiver= Public_key.Compressed.empty; amount= Amount.zero}

[%%ifdef
consensus_mechanism]

type var = (Public_key.Compressed.var, Amount.var) Poly.t

let typ : (var, t) Typ.t =
  let spec =
    let open Data_spec in
    [Public_key.Compressed.typ; Amount.typ]
  in
  let of_hlist : 'a 'b. (unit, 'a -> 'b -> unit) H_list.t -> ('a, 'b) Poly.t =
    let open H_list in
    fun [receiver; amount] -> {receiver; amount}
  in
  let to_hlist Poly.{receiver; amount} = H_list.[receiver; amount] in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let to_input {Poly.receiver; amount} =
  Random_oracle.Input.(
    append
      (Public_key.Compressed.to_input receiver)
      (bitstring (Amount.to_bits amount)))

let var_to_input {Poly.receiver; amount} =
  Random_oracle.Input.(
    append
      (Public_key.Compressed.Checked.to_input receiver)
      (bitstring
         (Bitstring_lib.Bitstring.Lsb_first.to_list (Amount.var_to_bits amount))))

let var_of_t ({receiver; amount} : t) : var =
  { receiver= Public_key.Compressed.var_of_t receiver
  ; amount= Amount.var_of_t amount }

[%%endif]

let gen ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%map receiver = Public_key.Compressed.gen
  and amount = Amount.gen_incl Amount.zero max_amount in
  Poly.{receiver; amount}
