(* Account states: accounts_accessed rows written by the archive's own writer,
   read back with its loaders. And the schema scripts run on a built database:
   downgrade.sql then upgrade.sql must give every row and index back. *)

open Core
open Async
module B = Synthetic_archive
module P = Archive_lib.Processor

let timing =
  { B.initial_minimum_balance = 600
  ; cliff_time = 10
  ; cliff_amount = 100
  ; vesting_period = 5
  ; vesting_increment = 50
  }

let test server_uri () =
  let s = B.create () in
  let alice = B.account s "alice" and bob = B.account s "bob" in
  let b1 = B.block s ~name:"b1" ~height:1 Canonical in
  B.account_state ~nonce:2 s b1 alice ~balance:400 ;
  B.account_state ~timing s b1 bob ~balance:1_000 ;
  B.Db.with_fresh ~server_uri ~name:"test_synthetic_archive_account_states"
    (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind built = B.materialize s db in
      Deferred.ok
      @@ B.Db.with_connection db (fun conn ->
             let open Deferred.Let_syntax in
             let%bind rows =
               Read_back.ok ~ctx:"accounts accessed"
                 (P.Accounts_accessed.all_from_block conn (B.block_id built b1))
             in
             let%map states =
               Deferred.List.map ~how:`Sequential rows
                 ~f:(fun (row : P.Accounts_accessed.t) ->
                   let%bind pk =
                     Read_back.public_key_of_identifier conn
                       row.account_identifier_id
                   in
                   let%map t =
                     Read_back.ok ~ctx:"timing info"
                       (P.Timing_info.load conn row.timing_id)
                   in
                   sprintf "%s balance=%s nonce=%Ld timing=%s/%Ld/%s/%Ld/%s" pk
                     row.balance row.nonce t.initial_minimum_balance
                     t.cliff_time t.cliff_amount t.vesting_period
                     t.vesting_increment )
             in
             Alcotest.(check (list string))
               "accounts_accessed, with the timing the archive writes"
               (List.sort ~compare:String.compare
                  [ sprintf "%s balance=400 nonce=2 timing=0/0/0/0/0"
                      (B.public_key alice)
                  ; sprintf "%s balance=1000 nonce=0 timing=600/10/100/5/50"
                      (B.public_key bob)
                  ] )
               (List.sort ~compare:String.compare states) ) )

(* The schema scripts on an archive with data: downgrade.sql then upgrade.sql
   gives the archive back unchanged: every row, index, column, constraint and
   sequence, and migration_history ends at the upgrade's version, applied. The
   checks name no table, column or index, so a change to the scripts needs no
   change here.

   downgrade.sql may refuse the data: a token symbol or zkApp URI that is not
   valid in the database encoding cannot become text. Then it must leave the
   archive in a state that upgrade.sql brings back to the original. Each round
   trip states which outcome it expects, so a change in either direction
   shows.

   The database is made from create_schema.sql and then upgrade.sql, as an
   upgraded archive is: downgrade.sql places a database with no
   migration_history at create_schema_protocol_version, which is not the
   version it rolls back from, and refuses it. *)

(* one column of strings, in the query's order *)
let strings db ~ctx query =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      Read_back.ok ~ctx
        (Conn.collect_list
           (Mina_caqti.collect_req Caqti_type.unit Caqti_type.string query)
           () ) )

(* every table but migration_history, which the scripts write to *)
let table_names db =
  strings db ~ctx:"table names"
    "SELECT quote_ident(table_name) FROM information_schema.tables WHERE \
     table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name <> \
     'migration_history' ORDER BY table_name"

(* a table's rows as text, in a fixed order *)
let table_rows (module Conn : Mina_caqti.CONNECTION) table =
  Read_back.ok ~ctx:("rows of " ^ table)
    (Conn.find
       (Caqti_request.Infix.(Caqti_type.unit ->! Caqti_type.string)
          ~oneshot:true
          (sprintf
             "SELECT COALESCE(string_agg(t::text, E'\\n' ORDER BY t::text), \
              '') FROM public.%s t"
             table ) )
       () )

let all_rows db =
  let%bind tables = table_names db in
  B.Db.with_connection db (fun conn ->
      Deferred.List.map ~how:`Sequential tables ~f:(fun table ->
          let%map rows = table_rows conn table in
          (table, rows) ) )

(* The schema, as lists that name nothing: a change the round trip does not
   undo shows in one of them. migration_history is left out, as above. *)
let schema =
  [ ( "indexes"
    , "SELECT indexdef FROM pg_indexes WHERE schemaname = 'public' AND \
       tablename <> 'migration_history' ORDER BY indexdef" )
  ; ( "columns"
    , "SELECT table_name || '.' || column_name || ' ' || data_type || ' null=' \
       || is_nullable || ' default=' || COALESCE(column_default, '') FROM \
       information_schema.columns WHERE table_schema = 'public' AND table_name \
       <> 'migration_history' ORDER BY 1" )
  ; ( "constraints"
    , "SELECT conrelid::regclass::text || ' ' || conname || ' ' || \
       pg_get_constraintdef(oid) FROM pg_constraint WHERE connamespace = \
       'public'::regnamespace AND conrelid::regclass::text <> \
       'migration_history' ORDER BY 1" )
    (* a table the scripts recreate would start its serial again *)
  ; ( "sequences"
    , "SELECT sequencename || ' ' || COALESCE(last_value::text, 'unused') FROM \
       pg_sequences WHERE schemaname = 'public' ORDER BY 1" )
  ]

(* the newest migration_history row: protocol version, migration version,
   status *)
let newest_migration db =
  strings db ~ctx:"migration_history"
    "SELECT protocol_version || ' ' || migration_version || ' ' || \
     status::text FROM migration_history ORDER BY commit_start_at DESC LIMIT 1"

let check_same_state ~msg ~expected db =
  let%bind expected_rows = all_rows expected in
  let%bind rows = all_rows db in
  Alcotest.(check (list (pair string string)))
    (msg ^ ": rows") expected_rows rows ;
  let%bind () =
    Deferred.List.iter ~how:`Sequential schema ~f:(fun (what, query) ->
        let%bind want = strings expected ~ctx:what query in
        let%map got = strings db ~ctx:what query in
        Alcotest.(check (list string)) (msg ^ ": " ^ what) want got )
  in
  (* The copy is at the upgrade's version, applied. The archive must end
     there, or the next run of either script takes another branch. *)
  let%bind want = newest_migration expected in
  Alcotest.(check bool)
    (msg ^ ": the copy's newest migration is applied")
    true
    (List.for_all want ~f:(String.is_suffix ~suffix:" applied")) ;
  let%map got = newest_migration db in
  Alcotest.(check (list string))
    (msg ^ ": newest migration_history row")
    want got

(* payments, a delegation, a zkApp command that sets [token_symbol] and
   [zkapp_uri] and one that sets an empty symbol and URI, a coinbase, an
   orphaned block *)
let scripts_scenario ~token_symbol ~zkapp_uri =
  let s = B.create () in
  let alice = B.account s "alice" and bob = B.account s "bob" in
  let b1 = B.block s ~name:"b1" ~height:1 Canonical in
  let b2 = B.block s ~name:"b2" ~height:2 ~parent:b1 Canonical in
  let o2 = B.block s ~name:"o2" ~height:2 ~parent:b1 Orphaned in
  let (_ : B.user_command) =
    B.payment s ~name:"pay" ~source:alice ~receiver:bob
      ~in_:[ (b2, Applied); (o2, Applied) ]
  in
  let (_ : B.user_command) =
    B.delegation s ~name:"deleg" ~delegator:alice ~delegate:bob
      ~in_:[ (b2, Applied) ]
  in
  let (_ : B.zkapp_command) =
    B.zkapp_command s ~name:"zk" ~fee_payer:alice
      ~account_updates:
        [ B.account_update ~token_symbol ~zkapp_uri ~balance_change:3 bob
        ; B.account_update ~token_symbol:"" ~zkapp_uri:"" alice
        ]
      ~in_:[ (b2, Applied) ]
  in
  let (_ : B.coinbase) = B.coinbase s ~name:"cb" ~receiver:bob b2 in
  B.account_created s b2 bob ; s

(* downgrade.sql then upgrade.sql on an upgraded archive holding
   [scripts_scenario], in a database of [encoding], compared with a copy made
   before *)
let round_trip ~server_uri ~name ~encoding ~token_symbol ~zkapp_uri
    ~(downgrade : [ `Succeeds | `Refused ]) =
  B.Db.with_fresh ~upgrade:true ~encoding ~server_uri ~name (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : B.built) =
        B.materialize (scripts_scenario ~token_symbol ~zkapp_uri) db
      in
      let%bind copy = B.Db.copy db ~name:(name ^ "_copy") in
      let%bind.Deferred result =
        Monitor.try_with_or_error (fun () ->
            let open Deferred.Let_syntax in
            let%bind result = B.Db.run_script db `Rollback in
            ( match (downgrade, result) with
            | `Succeeds, Ok () | `Refused, Error _ ->
                ()
            | `Succeeds, Error e ->
                Error.raise (Error.tag e ~tag:"downgrade failed")
            | `Refused, Ok () ->
                failwith "downgrade succeeded, but it must refuse this data" ) ;
            let%bind () =
              B.Db.run_script db `Upgrade
              >>| Or_error.tag ~tag:"upgrade failed"
              >>| ok_exn
            in
            check_same_state ~msg:"after downgrade and upgrade" ~expected:copy
              db )
      in
      let%bind () = B.Db.drop copy in
      Deferred.return result )

(* The values are bytes. The scripts re-encode them, convert_from in
   downgrade.sql and convert_to in upgrade.sql, so the valid values must not
   be ASCII: ASCII is the same bytes in every encoding, and a wrong encoding
   in either step would give them back unchanged. "MÏNA" is 5 bytes of UTF-8,
   within the 6 bytes of a token symbol. *)
let test_run_script server_uri () =
  let open Deferred.Or_error.Let_syntax in
  let round_trip = round_trip ~server_uri in
  (* valid UTF-8: the downgrade must work, and the upgrade must undo it *)
  let%bind () =
    round_trip ~name:"test_synthetic_archive_run_script" ~encoding:"UTF8"
      ~token_symbol:"MÏNA" ~zkapp_uri:"https://example.com/zkäpp"
      ~downgrade:`Succeeds
  in
  (* a lone 0xff, as on mainnet, is not UTF-8: the downgrade refuses it at
     token_symbols *)
  let%bind () =
    round_trip ~name:"test_synthetic_archive_run_script_symbol_not_utf8"
      ~encoding:"UTF8" ~token_symbol:"\xff"
      ~zkapp_uri:"https://example.com/zkapp" ~downgrade:`Refused
  in
  (* a URI that is not UTF-8 after a valid symbol: the downgrade refuses it at
     zkapp_uris. Both tables convert in one statement, so token_symbols is
     rolled back with it. *)
  let%bind () =
    round_trip ~name:"test_synthetic_archive_run_script_uri_not_utf8"
      ~encoding:"UTF8" ~token_symbol:"MÏNA"
      ~zkapp_uri:"https://example.com/\xff" ~downgrade:`Refused
  in
  (* a SQL_ASCII database keeps any byte but 0x00 as text: the downgrade takes
     the lone 0xff, and the upgrade must give the same byte back *)
  round_trip ~name:"test_synthetic_archive_run_script_sql_ascii"
    ~encoding:"SQL_ASCII" ~token_symbol:"\xff"
    ~zkapp_uri:"https://example.com/\xff" ~downgrade:`Succeeds
