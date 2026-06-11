open Core
open Async

module Ledger_entry = struct
  (*
The type that represents the ledger information we want to dump from the archive db
*)
  type t =
    { delegate_key : string option
    ; ledger_index : int
    ; balance : string
    ; nonce : int
    ; receipt_chain_hash : string
    ; ledger_hash : string
    ; token_symbol : string option
    ; timestamp : string
    }
  [@@deriving to_yojson]
end

module Database = struct
  module Utils = struct
    (*
    utilities so we can deserialize the Ledger_entry.t after making a
    request to Caqti
    *)
    let tup8 i1 i2 i3 i4 i5 i6 i7 i8 =
      let open Caqti_type in
      let first = t4 i1 i2 i3 i4 in
      let second = t4 i5 i6 i7 i8 in
      t2 first second
  end

  open Ledger_entry

  (* encoders and decoders for the ledger entry view *)
  let caqti_ledger_entry =
    let open Caqti_type in
    let encode
        { delegate_key
        ; ledger_index
        ; balance
        ; nonce
        ; receipt_chain_hash
        ; ledger_hash
        ; token_symbol
        ; timestamp
        } =
      Ok
        ( (delegate_key, ledger_index, balance, nonce)
        , (receipt_chain_hash, ledger_hash, token_symbol, timestamp) )
    in
    let decode
        ( (delegate_key, ledger_index, balance, nonce)
        , (receipt_chain_hash, ledger_hash, token_symbol, timestamp) ) =
      Ok
        { delegate_key
        ; ledger_index
        ; balance
        ; nonce
        ; receipt_chain_hash
        ; ledger_hash
        ; token_symbol
        ; timestamp
        }
    in
    custom ~encode ~decode
      Utils.(
        tup8 (option string) int string int string string (option string) string)
end

let json_error msg =
  eprintf "%s\n" (Yojson.Safe.to_string (`Assoc [ ("error", `String msg) ]))

let dump_slot slot postgres =
  let open Deferred.Let_syntax in
  let pool = Mina_caqti.connect_pool postgres in
  match pool with
  | Error e ->
      json_error
        (sprintf "Failed to create a Caqti pool for Postgresql: %s"
           (Caqti_error.show e) ) ;
      Deferred.unit
  | Ok pool -> (
      let slot_string = Mina_numbers.Global_slot_since_genesis.to_string slot in
      let entries =
        (*
      This query dumps all the ledger information tied to each account.
      The assumption here is the chain state for a slot corresponds to the
      closest block produced before or at the given slot. This is because
      a block is produced during a slot, but not every slot has a block.
      *)
        Mina_caqti.collect_req Caqti_type.unit Database.caqti_ledger_entry
        @@ sprintf
             {sql|
      WITH SlotBlock AS (
        SELECT id, ledger_hash, timestamp
        FROM blocks
        WHERE global_slot_since_genesis <= %s
        ORDER BY global_slot_since_genesis DESC
        LIMIT 1
      )

      SELECT
        pks.value AS delegate_key,
        accts.ledger_index,
        accts.balance,
        accts.nonce,
        accts.receipt_chain_hash,
        block.ledger_hash,
        tickers.value,
        block.timestamp
      FROM accounts_accessed accts
      INNER JOIN token_symbols tickers on accts.token_symbol_id = tickers.id
      LEFT JOIN public_keys pks on accts.delegate_id = pks.id
      INNER JOIN (SELECT id, ledger_hash, timestamp from SlotBlock) block
      ON block.id = accts.block_id
    |sql}
             slot_string
      in
      let%bind ledger =
        Mina_caqti.Pool.use
          (fun (module Conn : Mina_caqti.CONNECTION) ->
            Conn.collect_list entries ()
            >>| function
            | Ok rows ->
                List.iter rows ~f:(fun row ->
                    printf "%s\n"
                      (Yojson.Safe.to_string (Ledger_entry.to_yojson row)) ) ;
                Ok ()
            | Error e ->
                json_error
                  (sprintf
                     "Failed to obtain ledger entries from the database: %s"
                     (Caqti_error.show e) ) ;
                Ok () )
          pool
      in

      match ledger with
      | Ok () ->
          Deferred.unit
      | Error e ->
          json_error
            (sprintf
               "Failed to obtain entries after the initial ledger query: %s"
               (Caqti_error.show e) ) ;
          Deferred.unit )

let command =
  Command.async
    ~summary:
      "Prints out the ledger for a given slot for debugging purposes. \n\
      \  It requires an archive db url and a slot number"
    (let%map_open.Command postgres = Lazy.force Cli_lib.Flag.Uri.Archive.postgres
     and slot =
       flag "--slot" ~aliases:[ "slot" ]
         ~doc:"the global slot since genesis that you would like to dump"
         (required Cli_lib.Arg_type.global_slot)
     in
     fun () -> dump_slot slot postgres.value )

let () = Command.run command
