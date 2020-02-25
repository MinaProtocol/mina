open Core
open Snark_params.Tick
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
    type t = (Account_id.Stable.V1.t, Amount.Stable.V1.t) Poly.Stable.V1.t
    [@@deriving compare, eq, sexp, hash, compare, yojson]

    let to_latest = Fn.id
  end
end]

(* bin_io, version omitted *)
type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

let dummy = Poly.{receiver= Account_id.empty; amount= Amount.zero}

type var = (Account_id.var, Amount.var) Poly.t

let typ : (var, t) Typ.t =
  let spec =
    let open Data_spec in
    [Account_id.typ; Amount.typ]
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
    append (Account_id.to_input receiver) (bitstring (Amount.to_bits amount)))

let var_to_input {Poly.receiver; amount} =
  Random_oracle.Input.(
    append
      (Account_id.Checked.to_input receiver)
      (bitstring
         (Bitstring_lib.Bitstring.Lsb_first.to_list (Amount.var_to_bits amount))))

let gen ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%map receiver = Account_id.gen
  and amount = Amount.gen_incl Amount.zero max_amount in
  Poly.{receiver; amount}

let var_of_t ({receiver; amount} : t) : var =
  {receiver= Account_id.var_of_t receiver; amount= Amount.var_of_t amount}
