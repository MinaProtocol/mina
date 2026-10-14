(* populate-genesis-accounts: a fork config's genesis ledger lands in
   genesis_accounts at the fork genesis height, once. *)

open Core
open Async
open Archive_hardfork_toolbox_lib
module B = Synthetic_archive

(* A fork config with [balances]: the fork genesis is at height 101. *)
let write_fork_config ~balances =
  let accounts =
    List.map balances ~f:(fun balance ->
        let pk =
          Signature_lib.(
            Public_key.compress (Keypair.create ()).public_key
            |> Public_key.Compressed.to_base58_check)
        in
        { Runtime_config.Accounts.Single.default with
          pk
        ; balance = Currency.Balance.of_mina_int_exn balance
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
  let file = Filename.temp_dir "populate_genesis" "" ^/ "fork_config.json" in
  Yojson.Safe.to_file file (Runtime_config.to_yojson config) ;
  (file, accounts)

let populate (db : B.Db.t) file =
  Logic.populate_genesis_accounts ~postgres_uri:db.uri ~runtime_config_file:file
    ~chunks_length:2 ()

let rows_at_height (db : B.Db.t) =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      Conn.find
        (Caqti_request.Infix.( ->! ) Caqti_type.unit Caqti_type.int
           "SELECT count(*)::int FROM genesis_accounts WHERE genesis_height = \
            101" )
        ()
      >>| Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e)) )

let balance_of (db : B.Db.t) (account : Runtime_config.Accounts.Single.t) =
  B.Db.with_connection db (fun conn ->
      Archive_lib.Processor.Genesis_accounts.latest conn ~public_key:account.pk
        ~token:Mina_base.Token_id.(to_string default)
        ~height:101L
      >>| Result.map_error ~f:(fun e -> Error.of_string (Caqti_error.show e)) )

let writes_the_ledger_once server_uri () =
  let file, accounts = write_fork_config ~balances:[ 1000; 1001; 1002 ] in
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_populate_genesis" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () = Deferred.ok (populate db file) in
      let%bind rows = rows_at_height db in
      Alcotest.(check int) "rows" (List.length accounts) rows ;
      let%bind () =
        Deferred.Or_error.List.iter accounts ~f:(fun account ->
            let%map found = balance_of db account in
            Alcotest.(check (option string))
              "balance"
              (Some (Currency.Balance.to_string account.balance))
              (Option.map found ~f:(fun found -> found.row.balance)) )
      in
      let%bind () = Deferred.ok (populate db file) in
      let%map again = rows_at_height db in
      Alcotest.(check int)
        "rows after a second run" (List.length accounts) again )

let fails_without_the_table server_uri () =
  let file, _ = write_fork_config ~balances:[ 1000 ] in
  B.Db.with_fresh ~server_uri ~name:"test_toolbox_populate_no_table" (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind () =
        B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
            Conn.exec
              (Caqti_request.Infix.( ->. ) Caqti_type.unit Caqti_type.unit
                 "DROP TABLE genesis_accounts" )
              ()
            |> Deferred.map
                 ~f:
                   (Result.map_error ~f:(fun e ->
                        Error.of_string (Caqti_error.show e) ) ) )
      in
      match%map.Deferred Monitor.try_with (fun () -> populate db file) with
      | Ok () ->
          Alcotest.fail "expected a failure without the table"
      | Error exn ->
          let msg = Exn.to_string exn in
          if
            not (String.is_substring msg ~substring:"no genesis_accounts table")
          then Alcotest.failf "unexpected failure: %s" msg ;
          Ok () )

let tests ~server_uri =
  let run f () =
    Thread_safe.block_on_async_exn (f server_uri) |> Or_error.ok_exn
  in
  [ ("writes the ledger once", `Quick, run writes_the_ledger_once)
  ; ("fails without the table", `Quick, run fails_without_the_table)
  ]
