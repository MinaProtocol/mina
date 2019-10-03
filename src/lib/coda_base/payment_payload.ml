open Core
open Snark_params.Tick
open Import
open Module_version
module Amount = Currency.Amount
module Fee = Currency.Fee

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('pk, 'amount) t = {receiver: 'pk; amount: 'amount}
        [@@deriving bin_io, eq, sexp, hash, yojson, compare, version]
      end

      include T
    end

    module Latest = V1
  end

  type ('pk, 'amount) t = ('pk, 'amount) Stable.Latest.t =
    {receiver: 'pk; amount: 'amount}
  [@@deriving eq, sexp, hash, yojson, compare]
end

module Stable = struct
  module V1 = struct
    module T = struct
      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Amount.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving bin_io, compare, eq, sexp, hash, compare, yojson, version]
    end

    include T
    include Registration.Make_latest_version (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "payment_payload"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

(* bin_io, version omitted *)
type t = Stable.Latest.t [@@deriving eq, sexp, hash, yojson]

let dummy = Poly.{receiver= Public_key.Compressed.empty; amount= Amount.zero}

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

let length_in_triples =
  Public_key.Compressed.length_in_triples + Amount.length_in_triples

let gen ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%map receiver = Public_key.Compressed.gen
  and amount = Amount.gen_incl Amount.zero max_amount in
  Poly.{receiver; amount}

let var_of_t ({receiver; amount} : t) : var =
  { receiver= Public_key.Compressed.var_of_t receiver
  ; amount= Amount.var_of_t amount }
