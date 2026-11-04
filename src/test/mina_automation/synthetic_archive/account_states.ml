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
   gives every row and every index back unchanged. The checks name no table,
   column or index, so a change to the scripts needs no change here.

   downgrade.sql may refuse the data (today: a token symbol that is not valid
   UTF-8 cannot become text). Then it must leave the archive in a state that
   upgrade.sql brings back to the original.

   The database is made from create_schema.sql and then upgrade.sql, as an
   upgraded archive is: downgrade.sql places a database with no
   migration_history at create_schema_protocol_version, which is not the
   version it rolls back from, and refuses it. *)

(* every table but migration_history, which the scripts write to *)
let table_names (module Conn : Mina_caqti.CONNECTION) =
  Read_back.ok ~ctx:"table names"
    (Conn.collect_list
       (Mina_caqti.collect_req Caqti_type.unit Caqti_type.string
          "SELECT quote_ident(table_name) FROM information_schema.tables WHERE \
           table_schema = 'public' AND table_type = 'BASE TABLE' AND \
           table_name <> 'migration_history' ORDER BY table_name" )
       () )

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
  B.Db.with_connection db (fun conn ->
      let%bind tables = table_names conn in
      Deferred.List.map ~how:`Sequential tables ~f:(fun table ->
          let%map rows = table_rows conn table in
          (table, rows) ) )

(* every index, by its definition *)
let indexes db =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      Read_back.ok ~ctx:"indexes"
        (Conn.collect_list
           (Mina_caqti.collect_req Caqti_type.unit Caqti_type.string
              "SELECT indexdef FROM pg_indexes WHERE schemaname = 'public' \
               ORDER BY indexdef" )
           () ) )

let check_same_state ~msg ~expected db =
  let%bind expected_rows = all_rows expected in
  let%bind rows = all_rows db in
  Alcotest.(check (list (pair string string)))
    (msg ^ ": rows") expected_rows rows ;
  let%bind expected_indexes = indexes expected in
  let%map got = indexes db in
  Alcotest.(check (list string)) (msg ^ ": indexes") expected_indexes got

(* payments, a delegation, a zkApp command that sets [token_symbol] and a
   URI, a coinbase, an orphaned block *)
let scripts_scenario ~token_symbol =
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
        [ B.account_update ~token_symbol ~zkapp_uri:"https://example.com/zkapp"
            ~balance_change:3 bob
        ]
      ~in_:[ (b2, Applied) ]
  in
  let (_ : B.coinbase) = B.coinbase s ~name:"cb" ~receiver:bob b2 in
  B.account_created s b2 bob ; s

(* downgrade.sql then upgrade.sql on an upgraded archive holding
   [scripts_scenario ~token_symbol], compared with a copy made before *)
let round_trip ~server_uri ~name ~token_symbol ~downgrade_must_succeed =
  B.Db.with_fresh ~upgrade:true ~server_uri ~name (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : B.built) =
        B.materialize (scripts_scenario ~token_symbol) db
      in
      let%bind copy = B.Db.copy db ~name:(name ^ "_copy") in
      let%bind.Deferred result =
        Monitor.try_with_or_error (fun () ->
            let open Deferred.Let_syntax in
            let%bind downgrade = B.Db.run_script db `Rollback in
            if downgrade_must_succeed then
              Or_error.ok_exn (Or_error.tag downgrade ~tag:"downgrade failed") ;
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

let test_run_script server_uri () =
  let open Deferred.Or_error.Let_syntax in
  (* ordinary data: the downgrade must work, and the upgrade must undo it *)
  let%bind () =
    round_trip ~server_uri ~name:"test_synthetic_archive_run_script"
      ~token_symbol:"MINA" ~downgrade_must_succeed:true
  in
  (* data the downgrade may refuse: whatever it did, the upgrade must undo it *)
  round_trip ~server_uri ~name:"test_synthetic_archive_run_script_not_utf8"
    ~token_symbol:"\xff\x00z" ~downgrade_must_succeed:false
