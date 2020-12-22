(* sql.ml -- (Postgresql) SQL queries for ingesting subchain app *)

open Async_kernel
open Caqti_async
open Mina_base
open Archive_lib

let epoch_data_of_seed_and_ledger_hash seed ledger_hash : Epoch_data.Value.t =
  (* dummy fields, not entered into archive db *)
  let start_checkpoint = State_hash.dummy in
  let lock_checkpoint = State_hash.dummy in
  let epoch_length = Coda_numbers.Length.zero in
  (* dummy currency value *)
  let ledger =
    Epoch_ledger.Poly.{hash= ledger_hash; total_currency= Currency.Amount.zero}
  in
  {seed; ledger; start_checkpoint; lock_checkpoint; epoch_length}

module Block = struct
  type t =
    { state_hash: string
    ; parent_hash: string
    ; creator: string
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

  let add_if_doesn't_exist ~logger (module Conn : Caqti_async.CONNECTION)
      (block : Extensional_block.t) =
    let state_hash = State_hash.to_base58_check block.state_hash in
    match%map
      Conn.find_opt
        (Caqti_request.find_opt Caqti_type.string Caqti_type.int
           "SELECT id FROM blocks WHERE state_hash = ?")
        state_hash
    with
    | Some id ->
        [%log info] "Block with state hash already in database"
          ~metadata:[("state_hash", `String state_hash)] ;
        id
    | None ->
        [%log info] "Adding block with state hash"
          ~metadata:[("state_hash", `String state_hash)] ;
        let open Deferred.Result.Let_syntax in
        (* add all foreign key references inserted before adding entry to `blocks` *)
        let%bind creator_id =
          Processor.Public_key.add_if_doesn't_exist (module Conn) block.creator
        in
        let%bind block_winner_id =
          Processor.Public_key.add_if_doesn't_exist
            (module Conn)
            block.block_winner
        in
        let staking_epoch_ledger_data =
          epoch_data_of_seed_and_ledger_hash block.staking_epoch_seed
            block.staking_epoch_ledger_hash
        in
        let%bind staking_epoch_data_id =
          Processor.Epoch_data.add_if_doesn't_exist
            (module Conn)
            staking_epoch_ledger_data
        in
        let next_epoch_ledger_data =
          epoch_data_of_seed_and_ledger_hash block.next_epoch_seed
            block.next_epoch_ledger_hash
        in
        let%bind next_epoch_data_id =
          Processor.Epoch_data.add_if_doesn't_exist
            (module Conn)
            next_epoch_ledger_data
        in
        let%map snarked_ledger_hash_id =
          Processor.Snarked_ledger_hash.add_if_doesn't_exist
            (module Conn)
            block.snarked_ledger_hash
        in
        (* we omit parent_id, patch those in a later pass *)
        Conn.find
          (Caqti_request.find typ Caqti_type.int
             {| INSERT INTO blocks
                  (state_hash,parent_hash,creator_id,block_winner_id,
                   snarked_ledger_hash_id,staking_epoch_data_id,next_epoch_data_id,
                   ledger_hash,height,global_slot,global_slot_since_genesis,timestamp)
                RETURNING id
             |})
end

(* Archive_lib.Processor does not have the queries given here *)

module Epoch_data = struct
  let query =
    Caqti_request.find Caqti_type.int Caqti_type.string
      "SELECT seed from epoch_data WHERE id = ?"

  let run (module Conn : Caqti_async.CONNECTION) id = Conn.find query id
end
