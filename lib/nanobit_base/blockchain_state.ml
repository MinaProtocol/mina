open Core_kernel
open Coda_numbers
open Util
open Snark_params
open Tick
open Let_syntax

module Digest = Pedersen.Digest

let all_but_last_exn xs = fst (split_last_exn xs)

module Hash = State_hash

module Stable = struct
  module V1 = struct
    type ('ledger_builder_hash, 'ledger_hash, 'time) t_ =
      { ledger_builder_hash: 'ledger_builder_hash
      ; ledger_hash: 'ledger_hash
      ; timestamp: 'time }
    [@@deriving bin_io, sexp, fields, eq, compare, hash]

    type t = (Ledger_builder_hash.Stable.V1.t, Ledger_hash.Stable.V1.t, Block_time.Stable.V1.t) t_
    [@@deriving bin_io, sexp, eq, compare, hash]
  end
end

include Stable.V1

type var =
  ( Ledger_builder_hash.var
  , Ledger_hash.var
  , Block_time.Unpacked.var 
  ) t_

type value = t [@@deriving bin_io, sexp, eq, compare, hash]

let create_value ~ledger_builder_hash ~ledger_hash ~timestamp =
  { ledger_builder_hash; ledger_hash; timestamp }

let to_hlist { ledger_builder_hash; ledger_hash; timestamp } =
  H_list.([ ledger_builder_hash; ledger_hash; timestamp ])
let of_hlist : (unit, 'lbh -> 'lh -> 'ti -> unit) H_list.t -> ('lbh, 'lh, 'ti) t_ =
  H_list.(fun [ ledger_builder_hash; ledger_hash; timestamp ] -> { ledger_builder_hash; ledger_hash; timestamp })

let data_spec =
  let open Data_spec in
  [ Ledger_builder_hash.typ
  ; Ledger_hash.typ
  ; Block_time.Unpacked.typ
  ]

let typ : (var, value) Typ.t =
  Typ.of_hlistable data_spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let var_to_bits ({ ledger_builder_hash; ledger_hash; timestamp } : var) =
  let%map ledger_hash_bits = Ledger_hash.var_to_bits ledger_hash
  and ledger_builder_hash_bits = Ledger_builder_hash.var_to_bits ledger_builder_hash
  in
  ledger_builder_hash_bits
  @ ledger_hash_bits
  @ Block_time.Unpacked.var_to_bits timestamp

let fold ({ ledger_builder_hash; ledger_hash; timestamp } : value) =
  Ledger_builder_hash.fold ledger_builder_hash
  +> Ledger_hash.fold ledger_hash
  +> Block_time.Bits.fold timestamp

let to_bits ({ ledger_builder_hash; ledger_hash; timestamp } : value) =
  Ledger_builder_hash.to_bits ledger_builder_hash
  @ Ledger_hash.to_bits ledger_hash
  @ Block_time.Bits.to_bits timestamp

let bit_length =
  Ledger_builder_hash.length_in_bits + Ledger_hash.length_in_bits + Block_time.bit_length

let set_timestamp t timestamp = { t with timestamp }

let genesis_time =
  Time.of_date_ofday ~zone:Time.Zone.utc
    (Date.create_exn ~y:2018 ~m:Month.Feb ~d:2)
    Time.Ofday.start_of_day
  |> Block_time.of_time

let genesis =
  { ledger_builder_hash= Ledger_builder_hash.dummy
  ; ledger_hash= Ledger.merkle_root Genesis_ledger.ledger
  ; timestamp= genesis_time }

module Message = struct
  open Util
  open Tick

  type nonrec t = t

  type nonrec var = var

  let hash t ~nonce =
    let d =
      Pedersen.digest_fold Hash_prefix.signature
        (fold t +> List.fold nonce)
    in
    List.take (Field.unpack d) Scalar.length |> Scalar.pack

  let () = assert Insecure.signature_hash_function

  let hash_checked t ~nonce =
    let open Let_syntax in
    with_label __LOC__
      (let%bind bits = var_to_bits t in
       let%bind hash =
         Pedersen_hash.hash
           ~init:
             ( Hash_prefix.length_in_bits
             , Signature_curve.var_of_value Hash_prefix.signature.acc )
           (bits @ nonce)
       in
       let%map bs =
         Pedersen_hash.Digest.choose_preimage
         @@ Pedersen_hash.digest hash
       in
       List.take bs Scalar.length)
end

module Signature = Snarky.Signature.Schnorr (Tick) (Snark_params.Tick.Signature_curve) (Message)
