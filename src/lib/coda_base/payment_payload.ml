open Core
open Fold_lib
open Coda_numbers
open Snark_params.Tick
open Let_syntax
open Import
open Sha256_lib
module Amount = Currency.Amount
module Fee = Currency.Fee
module Memo = Payment_memo

module Stable = struct
  module V1 = struct
    type ('pk, 'amount, 'memo) t_ =
      {receiver: 'pk; amount: 'amount; memo: 'memo}
    [@@deriving bin_io, eq, sexp, hash]

    type t = (Public_key.Compressed.Stable.V1.t, Amount.Stable.V1.t, Memo.t) t_
    [@@deriving bin_io, eq, sexp, hash]
  end
end

include Stable.V1

let dummy =
  {receiver= Public_key.Compressed.empty; amount= Amount.zero; memo= Memo.dummy}

type var = (Public_key.Compressed.var, Amount.var, Memo.var) t_

let typ : (var, t) Typ.t =
  let spec =
    let open Data_spec in
    [Public_key.Compressed.typ; Amount.typ; Memo.typ]
  in
  let of_hlist
        : 'a 'b 'e. (unit, 'a -> 'b -> 'e -> unit) H_list.t -> ('a, 'b, 'e) t_
      =
    let open H_list in
    fun [receiver; amount; memo] -> {receiver; amount; memo}
  in
  let to_hlist {receiver; amount; memo} = H_list.[receiver; amount; memo] in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let fold {receiver; amount; memo} =
  let open Fold in
  Public_key.Compressed.fold receiver +> Amount.fold amount +> Memo.fold memo

(* TODO: This could be a bit more efficient by packing across triples,
   but I think the added confusion-possibility
   is not worth it. *)
let var_to_triples {receiver; amount; memo} =
  with_label __LOC__
    (let%map receiver = Public_key.Compressed.var_to_triples receiver in
     let amount = Amount.var_to_triples amount in
     let memo = Memo.var_to_triples memo in
     receiver @ amount @ memo)

let length_in_triples =
  Public_key.Compressed.length_in_triples + Amount.length_in_triples
  + Memo.length_in_triples

let to_triples t = Fold.to_list (fold t)

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%map receiver = Public_key.Compressed.gen
  and amount = Amount.gen
  and memo = String.gen_with_length Payment_memo.max_size_in_bytes Char.gen in
  {receiver; amount; memo= Memo.create_exn memo}

let%test_unit "to_bits" =
  let open Test_util in
  with_randomness 123456789 (fun () ->
      let input =
        { receiver=
            {Public_key.Compressed.x= Field.random (); is_odd= Random.bool ()}
        ; amount= Amount.of_int (Random.int Int.max_value)
        ; memo=
            Memo.create_exn
              (arbitrary_string ~len:Payment_memo.max_size_in_bytes) }
      in
      Test_util.test_to_triples typ fold var_to_triples input )

let var_of_t ({receiver; amount; memo} : t) : var =
  { receiver= Public_key.Compressed.var_of_t receiver
  ; amount= Amount.var_of_t amount
  ; memo= Memo.var_of_t memo }
