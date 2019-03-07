open Core
open Fold_lib
open Snark_params.Tick
open Import
open Module_version
module Amount = Currency.Amount
module Fee = Currency.Fee

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type ('pk, 'amount) t_ = {receiver: 'pk; amount: 'amount}
      [@@deriving bin_io, eq, sexp, hash, compare, yojson]

      type t = (Public_key.Compressed.Stable.V1.t, Amount.Stable.V1.t) t_
      [@@deriving bin_io, eq, sexp, hash, compare, yojson]
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

include Stable.Latest

let dummy = {receiver= Public_key.Compressed.empty; amount= Amount.zero}

type var = (Public_key.Compressed.var, Amount.var) t_

let typ : (var, t) Typ.t =
  let spec =
    let open Data_spec in
    [Public_key.Compressed.typ; Amount.typ]
  in
  let of_hlist : 'a 'b. (unit, 'a -> 'b -> unit) H_list.t -> ('a, 'b) t_ =
    let open H_list in
    fun [receiver; amount] -> {receiver; amount}
  in
  let to_hlist {receiver; amount} = H_list.[receiver; amount] in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let fold {receiver; amount} =
  let open Fold in
  Public_key.Compressed.fold receiver +> Amount.fold amount

(* TODO: This could be a bit more efficient by packing across triples,
   but I think the added confusion-possibility
   is not worth it. *)
let%snarkydef var_to_triples {receiver; amount} =
  let%map receiver = Public_key.Compressed.var_to_triples receiver in
  let amount = Amount.var_to_triples amount in
  receiver @ amount

let length_in_triples =
  Public_key.Compressed.length_in_triples + Amount.length_in_triples

let to_triples t = Fold.to_list (fold t)

let gen ~max_amount =
  let open Quickcheck.Generator.Let_syntax in
  let%map receiver = Public_key.Compressed.gen
  and amount = Amount.gen_incl Amount.zero max_amount in
  {receiver; amount}

let%test_unit "to_bits" =
  let open Test_util in
  with_randomness 123456789 (fun () ->
      let input =
        { receiver=
            {Public_key.Compressed.x= Field.random (); is_odd= Random.bool ()}
        ; amount= Amount.of_int (Random.int Int.max_value) }
      in
      Test_util.test_to_triples typ fold var_to_triples input )

let var_of_t ({receiver; amount} : t) : var =
  { receiver= Public_key.Compressed.var_of_t receiver
  ; amount= Amount.var_of_t amount }
