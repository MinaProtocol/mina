(* ingest_subchain.ml -- write missing subchain blocks to archive database *)

open Core_kernel
open Async
open Mina_base
open Signature_lib

module type Base58_decodable = sig
  type t

  val of_base58_check : string -> t Or_error.t
end

let process_logs ~logger pool () : unit Deferred.t =
  let open Archive_lib.Extensional_block.From_base58_check in
  let rec go () : unit Deferred.t =
    let open Deferred.Let_syntax in
    match%bind Reader.read_line (Lazy.force Reader.stdin) with
    | `Ok line -> (
      match Yojson.Safe.from_string line with
      | `Assoc items -> (
        match List.Assoc.find items ~equal:String.equal "message" with
        | Some (`String "Block contents") -> (
          match List.Assoc.find items ~equal:String.equal "metadata" with
          | Some (`Assoc block_items) ->
              let metadata_find key =
                match List.Assoc.find block_items ~equal:String.equal key with
                | Some (`String item) ->
                    item
                | None ->
                    failwithf "Expected to find %s in block metadata items" key
                      ()
              in
              (* using OCaml types for block items allows re-use of SQL code in Archive_lib *)
              let block =
                let state_hash =
                  metadata_find "state_hash" |> state_hash_of_base58_check
                in
                let parent_hash =
                  metadata_find "parent_hash" |> state_hash_of_base58_check
                in
                let creator =
                  metadata_find "creator" |> public_key_of_base58_check
                in
                let block_winner =
                  metadata_find "block_winner" |> public_key_of_base58_check
                in
                let snarked_ledger_hash =
                  metadata_find "snarked_ledger_hash"
                  |> frozen_ledger_hash_of_base58_check
                in
                let staking_epoch_seed =
                  metadata_find "staking_epoch_seed"
                  |> epoch_seed_of_base58_check
                in
                let staking_epoch_ledger_hash =
                  metadata_find "staking_epoch_ledger_hash"
                  |> frozen_ledger_hash_of_base58_check
                in
                let next_epoch_seed =
                  metadata_find "next_epoch_seed" |> epoch_seed_of_base58_check
                in
                let next_epoch_ledger_hash =
                  metadata_find "next_epoch_ledger_hash"
                  |> frozen_ledger_hash_of_base58_check
                in
                let ledger_hash =
                  metadata_find "ledger_hash" |> ledger_hash_of_base58_check
                in
                let height =
                  metadata_find "height" |> Unsigned.UInt32.of_string
                in
                let global_slot =
                  metadata_find "global_slot" |> Unsigned.UInt32.of_string
                in
                let global_slot_since_genesis =
                  metadata_find "global_slot_since_genesis"
                  |> Unsigned.UInt32.of_string
                in
                let timestamp =
                  metadata_find "timestamp" |> Int64.of_string
                  |> Block_time.of_int64
                in
                { Archive_lib.Extensional_block.state_hash
                ; parent_hash
                ; creator
                ; block_winner
                ; snarked_ledger_hash
                ; staking_epoch_seed
                ; staking_epoch_ledger_hash
                ; next_epoch_seed
                ; next_epoch_ledger_hash
                ; ledger_hash
                ; height
                ; global_slot
                ; global_slot_since_genesis
                ; timestamp }
              in
              Sql.Block.add pool block ; go ()
          | _ ->
              failwith "Expected metadata in log" )
        | _ ->
            (* log other than a block, skip *)
            go () )
      | _ ->
          failwithf "Expected JSON record, got:\n%s" line () )
    | `Eof ->
        return ()
  in
  [%log info] "Processing JSON block logs" ;
  go ()

let main ~archive_uri () =
  let logger = Logger.create () in
  let archive_uri = Uri.of_string archive_uri in
  match Caqti_async.connect_pool ~max_size:128 archive_uri with
  | Error e ->
      [%log fatal]
        ~metadata:[("error", `String (Caqti_error.show e))]
        "Failed to create a Caqti pool for Postgresql" ;
      exit 1
  | Ok pool ->
      [%log info] "Successfully created Caqti pool for Postgresql" ;
      process_logs ~logger pool () ;
      ()

let () =
  Command.(
    run
      (let open Let_syntax in
      async
        ~summary:
          "Ingest blocks from a subchain, write them to an archive database"
        (let%map archive_uri =
           Param.flag "--archive-uri"
             ~doc:
               "URI URI for connecting to the archive database (e.g., \
                postgres://$USER:$USER@localhost:5432/archiver)"
             Param.(required string)
         in
         main ~archive_uri)))
