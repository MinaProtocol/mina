open Core_kernel
open Util
open Snark_params
open Tick
open Let_syntax

module Digest = Pedersen.Digest

let all_but_last_exn xs = fst (split_last_exn xs)

module Hash = State_hash

module Stable = struct
  module V1 = struct
    (* Someday: It may well be worth using bitcoin's compact nbits for target values since
      targets are quite chunky *)
    type ('target, 'state_hash, 'ledger_builder_hash, 'ledger_hash, 'strength, 'time, 'signer_public_key) t_ =
      { next_difficulty: 'target
      ; previous_state_hash: 'state_hash
      ; ledger_builder_hash: 'ledger_builder_hash
      ; ledger_hash: 'ledger_hash
      ; strength: 'strength
      ; timestamp: 'time
      ; signer_public_key: 'signer_public_key }
    [@@deriving bin_io, sexp, fields, eq]

    type t = (Target.Stable.V1.t, State_hash.Stable.V1.t, Ledger_builder_hash.Stable.V1.t, Ledger_hash.Stable.V1.t, Strength.Stable.V1.t, Block_time.Stable.V1.t, Public_key.Compressed.Stable.V1.t) t_
    [@@deriving bin_io, sexp, eq]
  end
end

include Stable.V1

type var =
  ( Target.Unpacked.var
  , State_hash.var
  , Ledger_builder_hash.var
  , Ledger_hash.var
  , Strength.Unpacked.var
  , Block_time.Unpacked.var
  , Public_key.Compressed.var
  ) t_

type value = t

let to_hlist { next_difficulty; previous_state_hash; ledger_builder_hash; ledger_hash; strength; timestamp; signer_public_key } =
  H_list.([ next_difficulty; previous_state_hash; ledger_builder_hash; ledger_hash; strength; timestamp; signer_public_key ])
let of_hlist : (unit, 'ta -> 'sh -> 'lbh -> 'lh -> 'st -> 'ti -> 'spk -> unit) H_list.t -> ('ta, 'sh, 'lbh, 'lh, 'st, 'ti, 'spk) t_ =
  H_list.(fun [ next_difficulty; previous_state_hash; ledger_builder_hash; ledger_hash; strength; timestamp; signer_public_key ] -> { next_difficulty; previous_state_hash; ledger_builder_hash; ledger_hash; strength; timestamp; signer_public_key })

let data_spec =
  let open Data_spec in
  [ Target.Unpacked.typ
  ; State_hash.typ
  ; Ledger_builder_hash.typ
  ; Ledger_hash.typ
  ; Strength.Unpacked.typ
  ; Block_time.Unpacked.typ
  ; Public_key.Compressed.typ
  ]

let typ : (var, value) Typ.t =
  Typ.of_hlistable data_spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let to_bits ({ next_difficulty; previous_state_hash; ledger_builder_hash; ledger_hash; strength; timestamp; signer_public_key } : var) =
  let%map ledger_hash_bits = Ledger_hash.var_to_bits ledger_hash
  and previous_state_hash_bits = State_hash.var_to_bits previous_state_hash
  and ledger_builder_hash_bits = Ledger_builder_hash.var_to_bits ledger_builder_hash
  and signer_public_key_bits = Public_key.Compressed.var_to_bits signer_public_key
  in
  Target.Unpacked.var_to_bits next_difficulty
  @ previous_state_hash_bits
  @ ledger_builder_hash_bits
  @ ledger_hash_bits
  @ Strength.Unpacked.var_to_bits strength
  @ Block_time.Unpacked.var_to_bits timestamp
  @ signer_public_key_bits

let fold ({ next_difficulty; previous_state_hash; ledger_builder_hash; ledger_hash; strength; timestamp; signer_public_key } : value) ~init ~f =
  (Target.Bits.fold next_difficulty
  +> State_hash.fold previous_state_hash
  +> Ledger_builder_hash.fold ledger_builder_hash
  +> Ledger_hash.fold ledger_hash
  +> Strength.Bits.fold strength
  +> Block_time.Bits.fold timestamp
  +> Public_key.Compressed.fold signer_public_key) ~init ~f

let to_bits_unchecked ({ next_difficulty; previous_state_hash; ledger_builder_hash; ledger_hash; strength; timestamp; signer_public_key } : value) =
  Target.Bits.to_bits next_difficulty
  @ State_hash.to_bits previous_state_hash
  @ Ledger_builder_hash.to_bits ledger_builder_hash
  @ Ledger_hash.to_bits ledger_hash
  @ Strength.Bits.to_bits strength
  @ Block_time.Bits.to_bits timestamp
  @ Public_key.Compressed.to_bits signer_public_key

let hash t =
  Pedersen.State.update_fold Hash_prefix.blockchain_state
    (List.fold_left (to_bits_unchecked t))
  |> Pedersen.State.digest
  |> State_hash.of_hash
