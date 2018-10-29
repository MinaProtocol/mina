open Core
open Import
open Snark_params
open Coda_numbers
open Tick
module Fee = Currency.Fee
module Payload = Transaction_payload

module Stable = struct
  module V1 = struct
    type ('payload, 'pk, 'signature) t_ =
      {payload: 'payload; sender: 'pk; signature: 'signature}
    [@@deriving bin_io, eq, sexp, hash]

    type t =
      (Payload.Stable.V1.t, Public_key.Stable.V1.t, Signature.Stable.V1.t) t_
    [@@deriving bin_io, eq, sexp, hash]

    type with_seed = string * t [@@deriving hash]

    let compare ~seed (t : t) (t' : t) =
      let same_sender = Public_key.equal t.sender t'.sender in
      let fee_compare = -Fee.compare t.payload.fee t'.payload.fee in
      if same_sender then
        (* We pick the one with a smaller nonce to go first *)
        let nonce_compare =
          Account_nonce.compare t.payload.nonce t'.payload.nonce
        in
        if nonce_compare <> 0 then nonce_compare else fee_compare
      else
        let hash x = hash_with_seed (seed, x) in
        if fee_compare <> 0 then fee_compare else hash t - hash t'
  end
end

include Stable.V1

type value = t

type var = (Payload.var, Public_key.var, Signature.var) t_

let public_keys ({payload= {Payload.receiver; _}; sender; _} : value) =
  [receiver; Public_key.compress sender]

let sign (kp : Signature_keypair.t) (payload : Payload.t) : t =
  { payload
  ; sender= kp.public_key
  ; signature= Schnorr.sign kp.private_key payload }

let typ : (var, t) Tick.Typ.t =
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

let gen ~keys ~max_amount ~max_fee =
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
    ; nonce= Account_nonce.zero }
  in
  sign sender payload

module With_valid_signature = struct
  type t = Stable.V1.t [@@deriving sexp, eq, bin_io]

  let compare = Stable.V1.compare

  let gen = gen
end

let check_signature ({payload; sender; signature} : t) =
  Schnorr.verify signature (Inner_curve.of_coords sender) payload

let%test_unit "completeness" =
  let keys = Array.init 2 ~f:(fun _ -> Signature_keypair.create ()) in
  Quickcheck.test ~trials:20 (gen ~keys ~max_amount:10000 ~max_fee:1000)
    ~f:(fun t -> assert (check_signature t) )

let check t = Option.some_if (check_signature t) t
