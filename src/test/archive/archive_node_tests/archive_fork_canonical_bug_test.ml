open Async
open Core
open Mina_automation
open Mina_automation_fixture.Archive

(** Reproduces the archive-side bug surfaced during the Bundle 5 dry-run
    hardfork (May 2026, pre-mesa network). When the fork point coincides with
    the prefork archive's last canonical block, post-fork (chain B) blocks
    land at heights below the archive's [greatest_canonical_height] and
    branch 2 of [Processor.update_chain_status] (processor.ml lines 4415-4446)
    walks chain A's parent links via [get_subchain] and silently re-canonicalizes
    chain A while orphaning chain B at the same heights.

    The test loads a prefork archive dump (chain A canonical up through 6818,
    pending tip ~7108), starts an archive process against the new HF runtime
    config, then feeds chain B's first four post-fork blocks (heights
    6816-6819, extensional format) and asserts that chain B is left in
    [pending] status rather than incorrectly orphaned.

    Expected behavior: today this test FAILS — the bug is live, chain B
    blocks come out [orphaned]. Once branch 2 of [update_chain_status] is
    made fork-aware, the test will start passing. *)

type t = before_bootstrap

(* State hashes from the live archive DB at the moment the bug fired —
   see the slack analysis in the Bundle 5 thread. *)
module Chain_a = struct
  let h_6816 = "3NL9pw82zro5zdQM4TSi26VzgoY8xCo29AGtZBBsNNbsgmMXU2p7"

  let h_6817 = "3NLsJegtqi16R5nMunHTBYx3siz8PCDmegD7wP7BnJgzY2wp8qNL"
end

module Chain_b = struct
  let h_6816 = "3NL5YRUKggVqZaGazgNhbWMydcSJnPQtcu5PBfyEwbsHboynPMP1"

  let h_6817 = "3NK3NxCrwhkRQbC2dg7XFQkCxhgzzugcxwD2wtfq8dZXPuty78wQ"
end

(* Filename inside [network_data.folder] for the prefork archive dump.
   Format: gzipped tar containing a single .sql file (pg_dump plain output). *)
let prefork_dump_archive = "prefork_archive_dump.sql.tar.gz"

(* The dump hardcodes the target db name to "archive" via [CREATE DATABASE
   archive] + [\connect archive]. We honor that rather than rewriting the
   dump. *)
let dump_target_db = "archive"

(* The dump applies its DDL inside a transaction-less psql session, so we
   need a connection to a db that already exists (postgres' default admin
   db) before [\connect archive] kicks in. *)
let admin_db = "postgres"

let strip_db_from_uri uri =
  match String.rsplit2 ~on:'/' uri with
  | Some (prefix, _db) when not (String.is_suffix prefix ~suffix:"/") ->
      prefix
  | _ ->
      uri

let restore_prefork_dump ~server_uri ~dump_archive_path ~dump_dir =
  let open Deferred.Let_syntax in
  let connection = Psql.Conn_str server_uri in
  Core.Unix.mkdir_p dump_dir ;
  let%bind _ = Utils.untar ~archive:dump_archive_path ~output:dump_dir in
  let files = Core.Sys.readdir dump_dir in
  let sql_file =
    Array.find files ~f:(String.is_suffix ~suffix:".sql")
    |> Option.value_exn ~here:[%here]
         ~message:
           (sprintf "no .sql file found after untarring %s" dump_archive_path)
  in
  let sql_path = dump_dir ^/ sql_file in
  let%bind _ =
    Psql.run_command ~connection
      (sprintf "DROP DATABASE IF EXISTS %s" dump_target_db)
  in
  let%map _ = Psql.run_script ~connection ~db:admin_db sql_path in
  ()

let query_chain_status ~archive_uri ~state_hash =
  let connection = Psql.Conn_str archive_uri in
  let query =
    sprintf "SELECT chain_status FROM blocks WHERE state_hash = '%s'"
      state_hash
  in
  match%map Psql.run_command ~connection query with
  | Ok s ->
      let s = String.strip s in
      if String.is_empty s then None else Some s
  | Error _ ->
      None

let assert_chain_b_not_orphaned ~archive_uri =
  let open Deferred.Let_syntax in
  let%bind chain_b_6816_status =
    query_chain_status ~archive_uri ~state_hash:Chain_b.h_6816
  in
  let%bind chain_b_6817_status =
    query_chain_status ~archive_uri ~state_hash:Chain_b.h_6817
  in
  let%bind chain_a_6816_status =
    query_chain_status ~archive_uri ~state_hash:Chain_a.h_6816
  in
  let%bind chain_a_6817_status =
    query_chain_status ~archive_uri ~state_hash:Chain_a.h_6817
  in
  let errors = ref [] in
  let check name actual expected =
    match actual with
    | Some s when String.equal (String.lowercase s) expected ->
        ()
    | Some s ->
        errors := sprintf "%s: expected %s, got %s" name expected s :: !errors
    | None ->
        errors := sprintf "%s: row missing in DB" name :: !errors
  in
  (* Chain B blocks were inserted by archive_blocks just now. The prefork
     dump's [greatest_canonical_height] is 6818 (branch 1 had legitimately
     canonicalized chain A out to 6818 because chain A's pending tip was at
     ~7108, k=290 hops above). When chain B 6816/6817 land below that
     threshold, branch 2 of [update_chain_status] fires and orphans them via
     a get_subchain walk that follows chain A's parent links. After the fix,
     chain B should be left as [pending]. *)
  check "chain_b_6816" chain_b_6816_status "pending" ;
  check "chain_b_6817" chain_b_6817_status "pending" ;
  (* Chain A's status from the dump should be untouched by the chain B
     inserts. *)
  check "chain_a_6816" chain_a_6816_status "canonical" ;
  check "chain_a_6817" chain_a_6817_status "canonical" ;
  if List.is_empty !errors then Deferred.return ()
  else
    failwithf
      "update_chain_status branch 2 mis-classified chain B after the \
       hardfork. Status snapshot:\n\
      \  %s"
      (String.concat ~sep:"\n  " !errors) ()

let test_case (test_data : t) =
  let open Deferred.Let_syntax in
  let server_uri = strip_db_from_uri test_data.config.postgres_uri in
  let archive_uri = server_uri ^ "/" ^ dump_target_db in
  let temp_dir = test_data.temp_dir in
  let dump_dir = temp_dir ^/ "dump" in
  let blocks_dir = temp_dir ^/ "chain_b_blocks" in
  let dump_archive_path =
    test_data.network_data.folder ^/ prefork_dump_archive
  in
  let%bind () =
    restore_prefork_dump ~server_uri ~dump_archive_path ~dump_dir
  in
  (* mina-archive-blocks writes directly to postgres and runs the same
     [update_chain_status] code path as the archive process, so we don't
     need to spawn an archive process to surface the bug. *)
  let%bind chain_b_blocks =
    let%map files =
      Network_data.untar_precomputed_blocks test_data.network_data
        blocks_dir
    in
    List.map files ~f:(fun f -> blocks_dir ^/ f)
    |> List.filter ~f:(String.is_suffix ~suffix:".json")
  in
  let%bind _ =
    Archive_blocks.run Archive_blocks.default ~blocks:chain_b_blocks
      ~archive_uri ~format:Archive_blocks.Extensional
  in
  match%map
    Monitor.try_with (fun () -> assert_chain_b_not_orphaned ~archive_uri)
  with
  | Ok () ->
      Mina_automation_fixture.Intf.Passed
  | Error exn ->
      Mina_automation_fixture.Intf.Failed
        (Error.of_exn ~backtrace:`Get exn)
