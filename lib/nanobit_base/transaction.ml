open Core
open Snark_params
open Tick
open Let_syntax
module Amount = Currency.Amount
module Fee = Currency.Fee

module Payload = struct
  module Stable = struct
    module V1 = struct
      type ('pk, 'amount, 'fee, 'nonce) t_ =
        {receiver: 'pk; amount: 'amount; fee: 'fee; nonce: 'nonce}
      [@@deriving bin_io, eq, sexp, compare, hash]

      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Amount.Stable.V1.t
        , Fee.Stable.V1.t
        , Account.Nonce.Stable.V1.t )
        t_
      [@@deriving bin_io, eq, sexp, compare, hash]
    end
  end

  include Stable.V1

  type value = t

  type var =
    ( Public_key.Compressed.var
    , Amount.var
    , Fee.var
    , Account.Nonce.Unpacked.var )
    t_

  let typ : (var, t) Tick.Typ.t =
    let spec =
      let open Data_spec in
      [ Public_key.Compressed.typ
      ; Amount.typ
      ; Fee.typ
      ; Account.Nonce.Unpacked.typ ]
    in
    let of_hlist
          : 'a 'b 'c 'd.    (unit, 'a -> 'b -> 'c -> 'd -> unit) H_list.t
            -> ('a, 'b, 'c, 'd) t_ =
      let open H_list in
      fun [receiver; amount; fee; nonce] -> {receiver; amount; fee; nonce}
    in
    let to_hlist {receiver; amount; fee; nonce} =
      H_list.[receiver; amount; fee; nonce]
    in
    Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

  let var_to_bits {receiver; amount; fee; nonce} =
    with_label __LOC__
      (let%map receiver = Public_key.Compressed.var_to_bits receiver in
       let amount = (Amount.var_to_bits amount :> Boolean.var list) in
       let fee = (Fee.var_to_bits fee :> Boolean.var list) in
       let nonce = Account.Nonce.Unpacked.var_to_bits nonce in
       receiver @ amount @ fee @ nonce)

  let to_bits {receiver; amount; fee; nonce} =
    Public_key.Compressed.to_bits receiver
    @ Amount.to_bits amount @ Fee.to_bits fee
    @ Account.Nonce.Bits.to_bits nonce

  let%test_unit "to_bits" =
    let open Test_util in
    with_randomness 123456789 (fun () ->
        let length = Field.size_in_bits + 64 + 32 in
        test_equal typ
          (Typ.list ~length Boolean.typ)
          var_to_bits to_bits
          { receiver= {x= Field.random (); is_odd= Random.bool ()}
          ; amount= Amount.of_int (Random.int Int.max_value)
          ; fee= Fee.of_int (Random.int Int.max_value_30_bits)
          ; nonce= Account.Nonce.random () } )
end

module Stable = struct
  module V1 = struct
    type ('payload, 'pk, 'signature) t_ =
      {payload: 'payload; sender: 'pk; signature: 'signature}
    [@@deriving bin_io, eq, sexp, compare, hash]

    type t =
      (Payload.Stable.V1.t, Public_key.Stable.V1.t, Signature.Stable.V1.t) t_
    [@@deriving bin_io, eq, sexp, compare, hash]

    let compare (t: t) (t': t) =
      let fee_compare = Fee.compare t.payload.fee t'.payload.fee in
      match fee_compare with 0 -> compare t t' | _ -> fee_compare
  end
end

include Stable.V1

type value = t

type var = (Payload.var, Public_key.var, Signature.var) t_

let sign (kp: Signature_keypair.t) (payload: Payload.t) : t =
  { payload
  ; sender= kp.public_key
  ; signature= Schnorr.sign kp.private_key (Payload.to_bits payload) }

let typ : (var, t) Tick.Typ.t =
  let spec = Data_spec.[Payload.typ; Public_key.typ; Signature.typ] in
  let of_hlist
        : 'a 'b 'c. (unit, 'a -> 'b -> 'c -> unit) H_list.t -> ('a, 'b, 'c) t_ =
    H_list.(fun [payload; sender; signature] -> {payload; sender; signature})
  in
  let to_hlist {payload; sender; signature} =
    H_list.[payload; sender; signature]
  in
  Typ.of_hlistable spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let gen ~keys ~max_amount ~max_fee =
  let open Quickcheck.Generator in
  let open Quickcheck.Generator.Let_syntax in
  let%map sender_idx = Int.gen_incl 0 (Array.length keys - 1)
  and receiver_idx = Int.gen_incl 0 (Array.length keys - 1)
  and fee = Int.gen_incl 0 max_fee >>| Currency.Fee.of_int
  and amount = Int.gen_incl 1 max_amount >>| Currency.Amount.of_int in
  let sender = keys.(sender_idx) in
  let receiver = keys.(receiver_idx) in
  let payload : Payload.t =
    { receiver= Public_key.compress receiver.Signature_keypair.public_key
    ; fee
    ; amount
    ; nonce= Account.Nonce.zero }
  in
  sign sender payload

module With_valid_signature = struct
  type t = Stable.V1.t [@@deriving sexp, eq, bin_io, compare]

  let gen = gen
end

let check_signature ({payload; sender; signature}: t) =
  Schnorr.verify signature sender (Payload.to_bits payload)

let check t = Option.some_if (check_signature t) t
