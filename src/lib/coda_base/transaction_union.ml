open Core_kernel
open Signature_lib
open Snark_params.Tick
open Currency
module Tag = Transaction_union_tag
module Payload = Transaction_union_payload

type ('payload, 'pk, 'signature) t_ =
  {payload: 'payload; sender: 'pk; signature: 'signature}
[@@deriving bin_io, eq, sexp, hash]

(* OK to use Latest, rather than Vn, because t is not bin_io'ed *)
type t = (Payload.t, Public_key.Stable.Latest.t, Signature.Stable.Latest.t) t_

type var = (Payload.var, Public_key.var, Signature.var) t_

let typ : (var, t) Typ.t =
  let spec = Data_spec.[Payload.typ; Public_key.typ; Schnorr.Signature.typ] in
  let of_hlist
        : 'a 'b 'c. (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) t_
      =
    H_list.(fun [payload; sender; signature] -> {payload; sender; signature})
  in
  let to_hlist {payload; sender; signature} =
    H_list.[payload; sender; signature]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

(** For SNARK purposes, we inject [Transaction.t]s into a single-variant 'tagged-union' record capable of
    representing all the variants. We interpret the fields of this union in different ways depending on
    the value of the [payload.body.tag] field, which represents which variant of [Transaction.t] the value
    corresponds to.

    Sometimes we interpret fields in surprising ways in different cases to save as much space in the SNARK as possible (e.g.,
    [payload.body.public_key] is interpreted as the recipient of a payment, the new delegate of a stake
    delegation command, and a fee transfer recipient for both coinbases and fee-transfers.
*)
let of_transaction : Transaction.t -> t = function
  | User_command cmd ->
      let {User_command.sender; payload; signature} =
        (cmd :> User_command.t)
      in
      { payload= Transaction_union_payload.of_user_command_payload payload
      ; sender
      ; signature }
  | Coinbase {proposer; fee_transfer; amount} ->
      let other_pk, other_amount =
        Option.value ~default:(proposer, Fee.zero) fee_transfer
      in
      { payload=
          { common=
              { fee= Amount.to_fee amount
              ; nonce= Account.Nonce.zero
              ; memo= User_command_memo.dummy }
          ; body=
              { public_key= other_pk
              ; amount= Amount.of_fee other_amount
              ; tag= Tag.Coinbase } }
      ; sender= Public_key.decompress_exn proposer
      ; signature= Signature.dummy }
  | Fee_transfer tr -> (
      let two (pk1, fee1) (pk2, fee2) : t =
        { payload=
            { common=
                { fee= fee2
                ; nonce= Account.Nonce.zero
                ; memo= User_command_memo.dummy }
            ; body=
                { public_key= pk1
                ; amount= Amount.of_fee fee1
                ; tag= Tag.Fee_transfer } }
        ; sender= Public_key.decompress_exn pk2
        ; signature= Signature.dummy }
      in
      match tr with
      | One (pk, fee) -> two (pk, fee) (pk, Fee.zero)
      | Two (t1, t2) -> two t1 t2 )

let excess (t : t) = Transaction_union_payload.excess t.payload

let supply_increase (t : t) =
  Transaction_union_payload.supply_increase t.payload
