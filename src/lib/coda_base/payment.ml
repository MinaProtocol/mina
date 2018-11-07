open Core
open Import
open Snark_params
open Coda_numbers
open Tick
module Fee = Currency.Fee
module Payload = Payment_payload

module T =
  Signed_payload.Make (struct
      let t = Hash_prefix.payment_payload
    end)
    (Payload)

module Stable = struct
  module V1 = struct
    type t = Payload.Stable.V1.t Signed_payload.Stable.V1.t
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

type var = T.var

let public_keys ({payload= {Payload.receiver; _}; sender; _} : value) =
  [receiver; Public_key.compress sender]

let sign = T.sign

let typ = T.typ

let gen_valid ~keys ~max_amount ~max_fee =
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

let gen ~keys ~max_amount ~max_fee =
  Quickcheck.Generator.map (gen_valid ~keys ~max_amount ~max_fee) ~f:(fun t ->
      (t :> T.t) )

module With_valid_signature = struct
  type t = T.With_valid_signature.t [@@deriving sexp, eq, bin_io]

  let compare ~seed (t1 : t) (t2 : t) =
    Stable.V1.compare ~seed (t1 :> T.t) (t2 :> T.t)

  let gen = gen_valid
end

module Checked = T.Checked
module Section = T.Section

let check = T.check

let%test_unit "completeness" =
  let keys = Array.init 2 ~f:(fun _ -> Signature_keypair.create ()) in
  Quickcheck.test ~trials:20 (gen ~keys ~max_amount:10000 ~max_fee:1000)
    ~f:(fun t -> assert (Option.is_some (check t)) )
