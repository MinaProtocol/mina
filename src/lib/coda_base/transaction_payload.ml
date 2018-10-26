open Core
open Fold_lib
open Coda_numbers
open Snark_params.Tick
open Let_syntax
open Import
module Amount = Currency.Amount
module Fee = Currency.Fee

module Stable = struct
  module V1 = struct
    type ('pk, 'amount, 'fee, 'nonce, 'memo) t_ =
      {receiver: 'pk; amount: 'amount; fee: 'fee; nonce: 'nonce; memo: 'memo}
    [@@deriving bin_io, eq, sexp, hash]

    type t =
      ( Public_key.Compressed.Stable.V1.t
      , Amount.Stable.V1.t
      , Fee.Stable.V1.t
      , Account_nonce.Stable.V1.t
      , Sha256.Digest.t )
      t_
    [@@deriving bin_io, eq, sexp, hash]
  end
end

include Stable.V1

let dummy =
  let dummy_memo = String.init (Sha256.Digest.length_in_bits / 8) ~f:(fun _ -> '\000') in
  { receiver= Public_key.Compressed.empty
  ; amount= Amount.zero
  ; fee= Fee.zero
  ; nonce= Account_nonce.zero
  ; memo= dummy_memo } (*TODO*)

type var =
  ( Public_key.Compressed.var
  , Amount.var
  , Fee.var
  , Account_nonce.Unpacked.var
  , Sha256.Digest.var )
  t_

let typ : (var, t) Typ.t =
  let spec =
    let open Data_spec in
    [Public_key.Compressed.typ; Amount.typ; Fee.typ; Account_nonce.Unpacked.typ; Sha256.Digest.typ]
  in
  let of_hlist
        : 'a 'b 'c 'd 'e.    (unit, 'a -> 'b -> 'c -> 'd -> 'e -> unit) H_list.t
          -> ('a, 'b, 'c, 'd, 'e) t_ =
    let open H_list in
    fun [receiver; amount; fee; nonce; memo] -> {receiver; amount; fee; nonce; memo}
  in
  let to_hlist {receiver; amount; fee; nonce; memo} =
    H_list.[receiver; amount; fee; nonce; memo]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let fold {receiver; amount; fee; nonce; memo} =
  let open Fold in
  Public_key.Compressed.fold receiver
  +> Amount.fold amount +> Fee.fold fee +> Account_nonce.fold nonce +> Sha256.Digest.fold memo

(* TODO: This could be a bit more efficient by packing across triples,
   but I think the added confusion-possibility
   is not worth it. *)
let var_to_triples {receiver; amount; fee; nonce; memo} =
  with_label __LOC__
    (let%map receiver = Public_key.Compressed.var_to_triples receiver in
     let amount = Amount.var_to_triples amount in
     let fee = Fee.var_to_triples fee in
     let nonce = Account_nonce.Unpacked.var_to_triples nonce in
     let memo = Fold.(to_list (group3 ~default:Boolean.false_ (of_list memo))) in
     receiver @ amount @ fee @ nonce @ memo)

let length_in_triples =
  Public_key.Compressed.length_in_triples + Amount.length_in_triples
  + Fee.length_in_triples + Account_nonce.length_in_triples + Sha256.Digest.length_in_triples

let to_triples t = Fold.to_list (fold t)

let gen =
  let open Quickcheck.Generator.Let_syntax in
  let%map receiver = Public_key.Compressed.gen
  and amount = Amount.gen
  and fee = Fee.gen
  and nonce = Account_nonce.gen
  and memo = String.gen_with_length (Sha256.Digest.length_in_bits / 8) Char.gen in
  {receiver; amount; fee; nonce; memo}

let%test_unit "to_bits" =
  let open Test_util in
  with_randomness 123456789 (fun () ->
      let input =
        { receiver=
            {Public_key.Compressed.x= Field.random (); is_odd= Random.bool ()}
        ; amount= Amount.of_int (Random.int Int.max_value)
        ; fee= Fee.of_int (Random.int Int.max_value_30_bits)
        ; nonce= Account_nonce.random ()
        ; memo= String.init (Sha256.Digest.length_in_bits / 8) ~f:(fun _ -> Char.of_int_exn (Random.int 256)) }
      in
      Test_util.test_to_triples typ fold var_to_triples input )

let var_of_t ({receiver; amount; fee; nonce; memo}: t) : var =
  { receiver= Public_key.Compressed.var_of_t receiver
  ; amount= Amount.var_of_t amount
  ; fee= Fee.var_of_t fee
  ; nonce= Account_nonce.Unpacked.var_of_value nonce 
  ; memo= Sha256_lib.Sha256.Digest.var_of_t memo }
