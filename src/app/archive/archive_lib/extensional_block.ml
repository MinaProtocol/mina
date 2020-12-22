(* extensional_block.ml *)

open Core_kernel
open Mina_base
open Signature_lib

(* the `blocks` table in the archive db uses foreign keys to refer to other
   tables; the type here fills in the data from those other tables, using
   their native OCaml types to assure the validity of the data
*)

type t =
  { state_hash: State_hash.t
  ; parent_hash: State_hash.t
  ; creator: Public_key.Compressed.t
  ; block_winner: Public_key.Compressed.t
  ; snarked_ledger_hash: Frozen_ledger_hash.t
  ; staking_epoch_seed: Epoch_seed.t
  ; staking_epoch_ledger_hash: Frozen_ledger_hash.t
  ; next_epoch_seed: Epoch_seed.t
  ; next_epoch_ledger_hash: Frozen_ledger_hash.t
  ; ledger_hash: Ledger_hash.t
  ; height: Unsigned.UInt32.t
  ; global_slot: Coda_numbers.Global_slot.t
  ; global_slot_since_genesis: Coda_numbers.Global_slot.t
  ; timestamp: Block_time.t }

let to_intensional_block t ~creator_id ~block_winner_id ~snarked_ledger_hash_id
    ~staking_epoch_data_id ~next_epoch_data_id : Processor.Block.t =
  let state_hash = State_hash.to_base58_check t.state_hash in
  let parent_id = None in
  (* not yet known *)
  let parent_hash = State_hash.to_base58_check t.parent_hash in
  let ledger_hash = Ledger_hash.to_base58_check t.ledger_hash in
  let height = Unsigned.UInt32.to_int64 t.height in
  let global_slot =
    Coda_numbers.Global_slot.to_uint32 t.global_slot
    |> Unsigned.UInt32.to_int64
  in
  let global_slot_since_genesis =
    Coda_numbers.Global_slot.to_uint32 t.global_slot
    |> Unsigned.UInt32.to_int64
  in
  ()

module From_base58_check = struct
  (* conversion functions from Base58check strings to types in `t` *)

  module type Base58_decodable = sig
    type t

    val of_base58_check : string -> t Or_error.t
  end

  let mk_of_base58_check (type t) (module M : Base58_decodable with type t = t)
      desc item : t =
    match M.of_base58_check item with
    | Ok v ->
        v
    | Error err ->
        failwithf "Base58Check decoding error for %s =\"%s\", error: %s" desc
          item (Error.to_string_hum err) ()

  let state_hash_of_base58_check =
    mk_of_base58_check (module State_hash) "state hash"

  let frozen_ledger_hash_of_base58_check =
    mk_of_base58_check (module Frozen_ledger_hash) "frozen ledger hash"

  let public_key_of_base58_check =
    mk_of_base58_check (module Public_key.Compressed) "public key compressed"

  let epoch_seed_of_base58_check =
    mk_of_base58_check (module Epoch_seed) "epoch seed"

  let ledger_hash_of_base58_check =
    mk_of_base58_check (module Ledger_hash) "ledger hash"
end
