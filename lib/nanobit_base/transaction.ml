open Core
open Snark_params
open Tick
open Let_syntax

module Amount = Currency.Amount
module Fee = Currency.Fee

module Payload = struct
  type ('pk, 'amount, 'fee) t_ =
    { receiver : 'pk
    ; amount   : 'amount
    ; fee      : 'fee
    }
  [@@deriving bin_io, sexp, compare]

  module Stable = struct
    module V1 = struct
      type t = (Public_key.Compressed.Stable.V1.t, Amount.Stable.V1.t, Fee.Stable.V1.t) t_
      [@@deriving bin_io, sexp, compare]
    end
  end

  include Stable.V1

  type value = t
  type var = (Public_key.Compressed.var, Amount.var, Fee.var) t_
  let typ : (var, t) Tick.Typ.t =
    let spec =
      Data_spec.(
        [ Public_key.Compressed.typ; Amount.typ; Fee.typ ])
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
      let amount = Amount.var_to_bits amount in
      let fee = Fee.var_to_bits fee in
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
        ; amount = Amount.of_int (Random.int Int.max_value)
        ; fee = Fee.of_int (Random.int Int.max_value_30_bits)
        })
end

module Stable = struct
  module V1 = struct
    type ('payload, 'pk, 'signature) t_ =
      { payload   : 'payload
      ; sender    : 'pk
      ; signature : 'signature
      }
    [@@deriving bin_io, sexp, compare]

    type t = (Payload.Stable.V1.t, Public_key.Stable.V1.t, Signature.Stable.V1.t) t_
    [@@deriving bin_io, sexp, compare]
  end
end

include Stable.V1

type value = t
type var = (Payload.var, Public_key.var, Signature.var) t_

let check_signature ({ payload; sender; signature } : t) =
  Tick.Schnorr.verify signature sender (Payload.to_bits payload)

let typ : (var, t) Tick.Typ.t =
  let spec =
    Data_spec.(
      [ Payload.typ; Public_key.typ; Signature.typ ])
  in
  let of_hlist : 'a 'b 'c. (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) t_ =
    H_list.(fun [ payload; sender; signature ] -> { payload; sender; signature })
  in
  let to_hlist { payload; sender; signature } = H_list.([ payload; sender; signature ]) in
  Typ.of_hlistable spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
