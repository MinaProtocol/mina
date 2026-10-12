(* The load-genesis-accounts command: a fork config's genesis ledger lands in
   genesis_accounts at the fork genesis height, once. Needs
   MINA_TEST_POSTGRES. *)

open Core
open Async
open Archive_hardfork_toolbox_lib
module B = Synthetic_archive

let num_accounts = 3

(* A fork config: the fork genesis is at height 101. *)
let write_fork_config dir =
  let accounts =
    List.init num_accounts ~f:(fun i ->
        let pk =
          Signature_lib.(
            Public_key.compress (Keypair.create ()).public_key
            |> Public_key.Compressed.to_base58_check)
        in
        { Runtime_config.Accounts.Single.default with
          pk
        ; balance = Currency.Balance.of_mina_int_exn (1000 + i)
        } )
  in
  let config =
    { Runtime_config.default with
      proof =
        Some
          (Runtime_config.Proof_keys.make
             ~fork:
               { state_hash =
                   "3NKeMoncuHab5ScarV5ViyF16cJPT4taWNSaTLS64Dp67wuXigPZ"
               ; blockchain_length = 100
               ; global_slot_since_genesis = 100
               }
             () )
    ; ledger = Some (Runtime_config.ledger_of_accounts accounts)
    }
  in
  let file = dir ^/ "fork_config.json" in
  Yojson.Safe.to_file file (Runtime_config.to_yojson config) ;
  file

let load (db : B.Db.t) file =
  Logic.load_genesis_accounts ~postgres_uri:db.uri ~runtime_config_file:file
    ~chunk_size:2 ()

let outcome = Alcotest.(pair int64 (pair int int))

let load db file = load db file >>|? fun (h, w, a) -> (h, (w, a))

let loads_once server_uri () =
  let file = write_fork_config (Filename.temp_dir "load_genesis" "") in
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_load_genesis" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind first = load db file in
      Alcotest.check outcome "written" (101L, (num_accounts, 0)) first ;
      let%map again = load db file in
      Alcotest.check outcome "already written" (101L, (0, num_accounts)) again )

let no_table server_uri () =
  let file = write_fork_config (Filename.temp_dir "load_genesis" "") in
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_load_genesis_no_table"
    (fun db ->
      let%bind.Deferred.Or_error () =
        B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
            Conn.exec
              (Caqti_request.Infix.( ->. ) Caqti_type.unit Caqti_type.unit
                 "DROP TABLE genesis_accounts" )
              ()
            >>| Result.map_error ~f:(fun e ->
                    Error.of_string (Caqti_error.show e) ) )
      in
      match%map load db file with
      | Ok _ ->
          Alcotest.fail "expected an error without the table"
      | Error e ->
          let msg = Error.to_string_hum e in
          if
            not (String.is_substring msg ~substring:"no genesis_accounts table")
          then Alcotest.failf "unexpected error: %s" msg ;
          Ok () )

let () =
  let uri = B.Db.test_server_uri () in
  let run f () = Thread_safe.block_on_async_exn (f uri) |> Or_error.ok_exn in
  Alcotest.run "archive_hardfork_toolbox"
    [ ( "load-genesis-accounts"
      , [ Alcotest.test_case "a fork config's ledger, then again" `Quick
            (run loads_once)
        ; Alcotest.test_case "a database without the table" `Quick
            (run no_table)
        ] )
    ]
