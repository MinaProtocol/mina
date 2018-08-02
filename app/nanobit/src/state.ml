open Core
open Async
open Nanobit_base
open Blockchain_snark

type t =
  { next_difficulty: Difficulty.t
  ; previous_state_hash: State_hash.Stable.V1.t
  ; ledger_builder_hash: Ledger_builder_hash.Stable.V1.t
  ; ledger_hash: Ledger_hash.Stable.V1.t
  ; strength: Strength.t
  ; timestamp: Block_time.Stable.V1.t }
[@@deriving sexp, fields, bin_io, compare, eq]

let to_blockchain_state
    { next_difficulty
    ; previous_state_hash
    ; ledger_builder_hash
    ; ledger_hash
    ; strength
    ; timestamp } : Blockchain_state.t =
  { next_difficulty
  ; previous_state_hash
  ; ledger_builder_hash
  ; ledger_hash
  ; strength
  ; timestamp }

let of_blockchain_state
    { Blockchain_state.next_difficulty
    ; previous_state_hash
    ; ledger_builder_hash
    ; ledger_hash
    ; strength
    ; timestamp } : t =
  { next_difficulty
  ; previous_state_hash
  ; ledger_builder_hash
  ; ledger_hash
  ; strength
  ; timestamp }

let zero = of_blockchain_state Blockchain_state.zero

let hash t = Blockchain_state.hash (to_blockchain_state t)

let create_pow t nonce = Proof_of_work.create (to_blockchain_state t) nonce
