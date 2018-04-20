open Core
open Async
open Nanobit_base
open Blockchain_snark

type t =
  { next_difficulty      : Difficulty.t
  ; previous_state_hash  : State_hash.Stable.V1.t
  ; ledger_hash          : Ledger_hash.Stable.V1.t
  ; strength             : Strength.t
  ; timestamp            : Block_time.t
  }
[@@deriving sexp, fields, bin_io]

let to_blockchain_state { next_difficulty; previous_state_hash; ledger_hash; strength; timestamp } : Blockchain_state.t =
  { next_difficulty; previous_state_hash; ledger_hash; strength; timestamp }

let of_blockchain_state { Blockchain_state.next_difficulty; previous_state_hash; ledger_hash; strength; timestamp } : t =
  { next_difficulty; previous_state_hash; ledger_hash; strength; timestamp }

let zero = of_blockchain_state Blockchain_state.zero

let hash t = Blockchain_state.hash (to_blockchain_state t)

let create_pow t nonce =
  let open Snark_params.Tick in
  Pedersen.hash_fold Pedersen.params
    (fun ~init ~f ->
       let init = List.fold (Blockchain_state.to_bits_unchecked (to_blockchain_state t)) ~init ~f in
       Nonce.Bits.fold nonce ~init ~f)

