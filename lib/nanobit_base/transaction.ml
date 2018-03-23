open Core
open Snark_params
open Snarky
open Tick
open Let_syntax

module Signature = Tick.Signature

module Amount = Currency.T64
module Fee = Currency.T32

module Payload = struct
  type ('pk, 'amount, 'fee) t_ =
    { receiver : 'pk
    ; amount   : 'amount
    ; fee      : 'fee
    }
  [@@deriving bin_io]

  type t = (Public_key.Compressed.t, Amount.t, Fee.t) t_
  [@@deriving bin_io]

  type value = t
  type var = (Public_key.Compressed.var, Amount.Unpacked.var, Fee.Unpacked.var) t_
  let typ : (var, t) Tick.Typ.t =
    let spec =
      Data_spec.(
        [ Public_key.Compressed.typ; Amount.Unpacked.typ; Fee.Unpacked.typ ])
    in
    let of_hlist : 'a 'b 'c. (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) t_ =
      H_list.(fun [ receiver; amount; fee ] -> { receiver; amount; fee })
    in
    let to_hlist { receiver; amount; fee } = H_list.([ receiver; amount; fee ]) in
    Typ.of_hlistable spec
      ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_bits { receiver; amount; fee } =
    with_label "Transaction.Payload.var_to_bits" begin
      let%map receiver = Public_key.Compressed.var_to_bits receiver in
      let amount = Amount.Unpacked.var_to_bits amount in
      let fee = Fee.Unpacked.var_to_bits fee in
      receiver @ amount @ fee
    end

  let to_bits { receiver; amount; fee } =
    Public_key.Compressed.to_bits receiver
    @ Amount.to_bits amount
    @ Fee.to_bits fee

  let%test_unit "to_bits" =
    let open Test_util in
    with_randomness 123456789 (fun () ->
      let length = Field.size_in_bits + 64 + 32 in
      test_equal typ (Typ.list ~length Boolean.typ) var_to_bits to_bits
        { receiver = { x = Field.random (); is_odd = Random.bool () }
        ; amount = Unsigned.UInt64.of_int (Random.int Int.max_value)
        ; fee = Unsigned.UInt32.of_int32 (Random.int32 Int32.max_value)
        })
end

type ('payload, 'pk, 'signature) t_ =
  { payload   : 'payload
  ; sender    : 'pk
  ; signature : 'signature
  }

type t = (Payload.t, Public_key.t, Signature.Signature.value) t_
type value = t
type var = (Payload.var, Public_key.var, Signature.Signature.var) t_

let typ : (var, t) Tick.Typ.t =
  let spec =
    Data_spec.(
      [ Payload.typ; Public_key.typ; Signature.Signature.typ ])
  in
  let of_hlist : 'a 'b 'c. (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) t_ =
    H_list.(fun [ payload; sender; signature ] -> { payload; sender; signature })
  in
  let to_hlist { payload; sender; signature } = H_list.([ payload; sender; signature ]) in
  Typ.of_hlistable spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
