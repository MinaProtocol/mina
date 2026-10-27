(* downgrade.sql then upgrade.sql on an archive with data gives every row
   back unchanged.

   The database is made from create_schema.sql and then upgrade.sql, as an
   upgraded archive is: downgrade.sql places a database with no
   migration_history at create_schema_protocol_version, which is not the
   version it rolls back from, and refuses it. *)

open Core
open Async
module B = Synthetic_archive

let ok ~ctx result = result >>| Mina_caqti.ok_exn ~ctx

(* every table but migration_history, which the scripts write to *)
let table_names (module Conn : Mina_caqti.CONNECTION) =
  ok ~ctx:"table names"
    (Conn.collect_list
       (Mina_caqti.collect_req Caqti_type.unit Caqti_type.string
          "SELECT quote_ident(table_name) FROM information_schema.tables WHERE \
           table_schema = 'public' AND table_type = 'BASE TABLE' AND \
           table_name <> 'migration_history' ORDER BY table_name" )
       () )

(* a table's rows as text, in a fixed order *)
let table_rows (module Conn : Mina_caqti.CONNECTION) table =
  ok ~ctx:("rows of " ^ table)
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

let check_same_rows ~msg ~expected db =
  let%bind expected = all_rows expected in
  let%map got = all_rows db in
  Alcotest.(check (list (pair string string))) msg expected got

let column_type db ~table =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      ok ~ctx:"column type"
        (Conn.find
           (Mina_caqti.find_req Caqti_type.string Caqti_type.string
              "SELECT data_type FROM information_schema.columns WHERE \
               table_schema = 'public' AND table_name = ? AND column_name = \
               'value'" )
           table ) )

let values db ~table =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      ok ~ctx:("values of " ^ table)
        (Conn.collect_list
           (Caqti_request.Infix.(Caqti_type.unit ->* Caqti_type.string)
              ~oneshot:true
              (sprintf "SELECT value::text FROM %s ORDER BY id" table) )
           () ) )

(* the account indexes upgrade.sql adds and downgrade.sql drops *)
let user_commands_indexes db =
  B.Db.with_connection db (fun (module Conn : Mina_caqti.CONNECTION) ->
      ok ~ctx:"user_commands indexes"
        (Conn.find
           (Mina_caqti.find_req Caqti_type.unit Caqti_type.int
              "SELECT count(*)::int FROM pg_indexes WHERE schemaname = \
               'public' AND indexname IN ('idx_user_commands_fee_payer_id', \
               'idx_user_commands_source_id', 'idx_user_commands_receiver_id')" )
           () ) )

let symbol = "MINA"

let uri = "https://example.com/zkapp"

(* payments, a delegation and a zkApp command that sets [token_symbol] *)
let scenario ~token_symbol =
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
        [ B.account_update ~token_symbol ~zkapp_uri:uri ~balance_change:3 bob ]
      ~in_:[ (b2, Applied) ]
  in
  let (_ : B.coinbase) = B.coinbase s ~name:"cb" ~receiver:bob b2 in
  B.account_created s b2 bob ; s

(* an upgraded archive with [scenario] in it, and a copy of it *)
let with_archive ~server_uri ~name ~token_symbol f =
  B.Db.with_fresh ~upgrade:true ~server_uri ~name (fun db ->
      let open Deferred.Or_error.Let_syntax in
      let%bind (_ : B.built) = B.materialize (scenario ~token_symbol) db in
      let%bind copy = B.Db.copy db ~name:(name ^ "_copy") in
      let%bind.Deferred result =
        Monitor.try_with_or_error (fun () -> f db ~copy)
      in
      let%bind () = B.Db.drop copy in
      Deferred.return (Or_error.join result) )

let run_ok db script =
  B.Db.run_script db script >>| Or_error.tag ~tag:"script failed" >>| ok_exn

(* a UTF-8 token symbol and URI go to text and come back as the same bytes *)
let test_utf8 server_uri () =
  with_archive ~server_uri ~name:"test_migration_round_trip"
    ~token_symbol:symbol (fun db ~copy ->
      let%bind () = run_ok db `Rollback in
      let%bind symbol_type = column_type db ~table:"token_symbols" in
      let%bind uri_type = column_type db ~table:"zkapp_uris" in
      Alcotest.(check string) "downgraded token symbol type" "text" symbol_type ;
      Alcotest.(check string) "downgraded zkapp uri type" "text" uri_type ;
      let%bind symbols = values db ~table:"token_symbols" in
      let%bind uris = values db ~table:"zkapp_uris" in
      Alcotest.(check (list string))
        "downgraded token symbols" [ symbol ] symbols ;
      Alcotest.(check (list string)) "downgraded zkapp uris" [ uri ] uris ;
      let%bind () = run_ok db `Upgrade in
      let%map () =
        check_same_rows ~msg:"rows after downgrade and upgrade" ~expected:copy
          db
      in
      Ok () )

(* text cannot hold a symbol that is not UTF-8: downgrade.sql stops, the
   column stays bytea, no row changes, and upgrade.sql runs again *)
let test_not_utf8 server_uri () =
  with_archive ~server_uri ~name:"test_migration_not_utf8"
    ~token_symbol:"\xff\x00z" (fun db ~copy ->
      let%bind rollback = B.Db.run_script db `Rollback in
      Alcotest.(check bool) "downgrade fails" true (Or_error.is_error rollback) ;
      (* it stops at the conversion: the step before it ran *)
      let%bind indexes = user_commands_indexes db in
      Alcotest.(check int) "user_commands indexes dropped" 0 indexes ;
      let%bind symbol_type = column_type db ~table:"token_symbols" in
      Alcotest.(check string)
        "token symbol type after the failed downgrade" "bytea" symbol_type ;
      let%bind () =
        check_same_rows ~msg:"rows after the failed downgrade" ~expected:copy db
      in
      let%bind () = run_ok db `Upgrade in
      let%map () =
        check_same_rows ~msg:"rows after the failed downgrade and upgrade"
          ~expected:copy db
      in
      Ok () )
