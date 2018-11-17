open Core
open Import
open Snark_params
open Coda_numbers
open Tick
module Fee = Currency.Fee
module Payload = User_command_payload

module Stable = struct
  module V1 = struct
    type ('payload, 'pk, 'signature) t_ =
      {payload: 'payload; sender: 'pk; signature: 'signature}
    [@@deriving bin_io, eq, sexp, hash, yojson]

    type t = (Payload.Stable.V1.t, Public_key.t, Signature.t) t_
    [@@deriving bin_io, eq, sexp, hash, yojson]

    type with_seed = string * t [@@deriving hash]

    let compare ~seed (t : t) (t' : t) =
      let same_sender = Public_key.equal t.sender t'.sender in
      let fee_compare =
        -Fee.compare (Payload.fee t.payload) (Payload.fee t'.payload)
      in
      if same_sender then
        (* We pick the one with a smaller nonce to go first *)
        let nonce_compare =
          Account_nonce.compare (Payload.nonce t.payload)
            (Payload.nonce t'.payload)
        in
        if nonce_compare <> 0 then nonce_compare else fee_compare
      else
        let hash x = hash_with_seed (seed, x) in
        if fee_compare <> 0 then fee_compare else hash t - hash t'
  end
end

include Stable.V1

type value = t

let payload {payload; _} = payload

let accounts_accessed ({payload; sender; _} : value) =
  Public_key.compress sender :: Payload.accounts_accessed payload

let sign (kp : Signature_keypair.t) (payload : Payload.t) : t =
  { payload
  ; sender= kp.public_key
  ; signature= Schnorr.sign kp.private_key payload }

let gen ~keys ~max_amount ~max_fee =
  let open Quickcheck.Generator.Let_syntax in
  let%map sender_idx = Int.gen_incl 0 (Array.length keys - 1)
  and receiver_idx = Int.gen_incl 0 (Array.length keys - 1)
  and fee = Int.gen_incl 0 max_fee >>| Currency.Fee.of_int
  and amount = Int.gen_incl 1 max_amount >>| Currency.Amount.of_int
  and memo = String.gen in
  let sender = keys.(sender_idx) in
  let receiver = keys.(receiver_idx) in
  let payload : Payload.t =
    Payload.create ~fee ~nonce:Account_nonce.zero
      ~memo:(User_command_memo.create_exn memo)
      ~body:
        (Payment
           { receiver= Public_key.compress receiver.Signature_keypair.public_key
           ; amount })
  in
  sign sender payload

module With_valid_signature = struct
  type t = Stable.V1.t [@@deriving sexp, eq, bin_io]

  let compare = Stable.V1.compare

  let gen = gen
end

let check_signature ({payload; sender; signature} : t) =
  Schnorr.verify signature (Inner_curve.of_coords sender) payload

let gen_test =
  let keys = Array.init 2 ~f:(fun _ -> Signature_keypair.create ()) in
  gen ~keys ~max_amount:10000 ~max_fee:1000

let%test_unit "completeness" =
  Quickcheck.test ~trials:20 gen_test ~f:(fun t -> assert (check_signature t))

let%test_unit "json" =
  Quickcheck.test ~trials:20 ~sexp_of:sexp_of_t gen_test ~f:(fun t ->
      assert (Codable.For_tests.check_encoding (module Stable.V1) ~equal t) )

let check t = Option.some_if (check_signature t) t
