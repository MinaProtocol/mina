(* missing_subchain.ml -- report available missing subchain from archive db *)

open Core_kernel
open Async
open Mina_base
open Signature_lib

(* the `blocks` table in the archive db uses foreign keys to refer to other
   tables; the type here fills in the data from those other tables, using
   their native OCaml types to assure the validity of the data
*)

module Extensional_block = struct
  type t =
    { state_hash: State_hash.t
    ; parent_hash: State_hash.t
    ; creator: Public_key.Compressed.t
    ; block_winner: Public_key.Compressed.t
    ; snarked_ledger_hash: Frozen_ledger_hash.t
    ; staking_epoch_data: Epoch_seed.t
    ; next_epoch_data: Epoch_seed.t
    ; ledger_hash: Ledger_hash.t
    ; height: Unsigned.UInt32.t
    ; global_slot: Coda_numbers.Global_slot.t
    ; global_slot_since_genesis: Coda_numbers.Global_slot.t
    ; timestamp: Block_time.t }
end

module type Base58_decodable = sig
  type t

  val of_base58_check : string -> t Or_error.t
end

let fill_in_block ~logger pool (block : Archive_lib.Processor.Block.t) :
    Extensional_block.t Deferred.t =
  let query_db ~f ~item =
    match%bind Caqti_async.Pool.use f pool with
    | Ok v ->
        return v
    | Error msg ->
        [%log error] "Error getting %s from db" item
          ~metadata:[("error", `String (Caqti_error.show msg))] ;
        exit 1
  in
  let mk_of_base58_check (type t) (module M : Base58_decodable with type t = t)
      desc item : t =
    match M.of_base58_check item with
    | Ok v ->
        v
    | Error err ->
        [%log error] "Error decoding Base58Check %s" desc
          ~metadata:
            [ ("base58_check", `String item)
            ; ("error", Error_json.error_to_yojson err) ] ;
        Core.exit 1
  in
  let state_hash_of_base58_check =
    mk_of_base58_check (module State_hash) "state hash"
  in
  let frozen_ledger_hash_of_base58_check =
    mk_of_base58_check (module Frozen_ledger_hash) "frozen ledger hash"
  in
  let public_key_of_base58_check =
    mk_of_base58_check (module Public_key.Compressed) "public key compressed"
  in
  let epoch_seed_of_base58_check =
    mk_of_base58_check (module Epoch_seed) "epoch seed"
  in
  let ledger_hash_of_base58_check =
    mk_of_base58_check (module Ledger_hash) "ledger hash"
  in
  let state_hash = state_hash_of_base58_check block.state_hash in
  let parent_hash = state_hash_of_base58_check block.parent_hash in
  let open Deferred.Let_syntax in
  let%bind creator_str =
    query_db
      ~f:(fun db -> Sql.Public_key.run db block.creator_id)
      ~item:"creator public key"
  in
  let creator = public_key_of_base58_check creator_str in
  let%bind block_winner_str =
    query_db
      ~f:(fun db -> Sql.Public_key.run db block.creator_id)
      ~item:"block winner public key"
  in
  let block_winner = public_key_of_base58_check block_winner_str in
  let%bind snarked_ledger_hash_str =
    query_db
      ~f:(fun db ->
        Sql.Snarked_ledger_hashes.run db block.snarked_ledger_hash_id )
      ~item:"snarked ledger hash"
  in
  let snarked_ledger_hash =
    frozen_ledger_hash_of_base58_check snarked_ledger_hash_str
  in
  let%bind staking_epoch_data_str =
    query_db
      ~f:(fun db -> Sql.Epoch_data.run db block.staking_epoch_data_id)
      ~item:"staking epoch data"
  in
  let staking_epoch_data = epoch_seed_of_base58_check staking_epoch_data_str in
  let%bind next_epoch_data_str =
    query_db
      ~f:(fun db -> Sql.Epoch_data.run db block.next_epoch_data_id)
      ~item:"next epoch data"
  in
  let next_epoch_data = epoch_seed_of_base58_check next_epoch_data_str in
  let ledger_hash = ledger_hash_of_base58_check block.ledger_hash in
  let height = Unsigned.UInt32.of_int64 block.height in
  let global_slot = Unsigned.UInt32.of_int64 block.global_slot in
  let global_slot_since_genesis =
    Unsigned.UInt32.of_int64 block.global_slot_since_genesis
  in
  let timestamp = Block_time.of_int64 block.timestamp in
  return
    { Extensional_block.state_hash
    ; parent_hash
    ; creator
    ; block_winner
    ; snarked_ledger_hash
    ; staking_epoch_data
    ; next_epoch_data
    ; ledger_hash
    ; height
    ; global_slot
    ; global_slot_since_genesis
    ; timestamp }

let main ~archive_uri ~state_hash () =
  let logger = Logger.create () in
  let archive_uri = Uri.of_string archive_uri in
  (* sanity-check input state hash *)
  ( match State_hash.of_base58_check state_hash with
  | Ok _ ->
      ()
  | Error err ->
      [%log error] "Error decoding input state hash"
        ~metadata:[("error", Error_json.error_to_yojson err)] ;
      Core.exit 1 ) ;
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[("error", `String (Caqti_error.show e))]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      [%log info] "Querying for subchain to block with given state hash" ;
      let%bind blocks =
        match%bind
          Caqti_async.Pool.use (fun db -> Sql.Subchain.run db state_hash) pool
        with
        | Ok blocks ->
            return blocks
        | Error msg ->
            [%log error] "Error getting blocks in subchain"
              ~metadata:[("error", `String (Caqti_error.show msg))] ;
            exit 1
      in
      if List.is_empty blocks then (
        [%log error]
          "No subchain available from genesis block to block with given state \
           hash" ;
        Core.exit 1 ) ;
      let%map extensional_blocks =
        Deferred.List.map blocks ~f:(fill_in_block ~logger pool)
      in
      let sorted_extensional_blocks =
        List.dedup_and_sort extensional_blocks
          ~compare:(fun (b1 : Extensional_block.t) b2 ->
            Unsigned.UInt32.compare b1.global_slot b2.global_slot )
      in
      [%log info] "Found a subchain of length %d"
        (List.length sorted_extensional_blocks) ;
      List.iter sorted_extensional_blocks ~f:(fun block ->
          [%log info] "Block contents"
            ~metadata:
              [ ("state_hash", State_hash.to_yojson block.state_hash)
              ; ("parent_hash", State_hash.to_yojson block.parent_hash)
              ; ("creator", Public_key.Compressed.to_yojson block.creator)
              ; ( "snarked_ledger_hash"
                , Frozen_ledger_hash.to_yojson block.snarked_ledger_hash )
              ; ( "staking_epoch_data"
                , Epoch_seed.to_yojson block.staking_epoch_data )
              ; ("next_epoch_data", Epoch_seed.to_yojson block.next_epoch_data)
              ; ("ledger_hash", Ledger_hash.to_yojson block.ledger_hash)
              ; ("height", Unsigned_extended.UInt32.to_yojson block.height)
              ; ( "global_slot"
                , Coda_numbers.Global_slot.to_yojson block.global_slot )
              ; ("timestamp", Block_time.to_yojson block.timestamp) ] ) ;
      ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async
        ~summary:
          "Report blocks in a subchain from the genesis block to a specific \
           block"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER:$USER@localhost:5432/archiver)"
             Param.(required string)
         and state_hash =
           Param.flag "--state-hash"
             ~doc:
               "State hash of the block that ends a chain from the genesis \
                block"
             Param.(required string)
         in
         main ~archive_uri ~state_hash)))
