open Async
open Core
open Mina_automation
module Audit = Missing_blocks_auditor_lib.Audit
module Auditor = Missing_blocks_guardian_lib.Auditor

(**
 * The audit of [mina-missing-blocks-auditor] and its missing-blocks check,
 * which [mina-missing-blocks-guardian] runs, on real databases:
 *
 * - a database with no schema: the first query fails;
 * - the schema with no block, and an archive whose blocks are all pending:
 *   the audit finds no canonical genesis or fork block and fails;
 * - the sample archive: no block is missing;
 * - the sample archive with one parent link removed: the check finds that
 *   parent.
 *
 * Each failure must be an [Error], so that neither program reports an
 * archive it could not read as healthy.
 *)

type t = Mina_automation_fixture.Archive.before_bootstrap

let logger = Logger.create ()

let connect uri =
  match Mina_caqti.connect_pool (Uri.of_string uri) with
  | Ok pool ->
      pool
  | Error err ->
      failwithf "Cannot connect to %s: %s" uri (Caqti_error.show err) ()

let sql ~uri command =
  Psql.run_command ~connection:(Psql.Conn_str uri) command
  >>| Or_error.ok_exn |> Deferred.ignore_m

(* [run] and [check] must both fail with [message]. *)
let expect_failure ~name ~pool ~message =
  let%bind () =
    match%map Audit.run ~logger ~pool with
    | Ok _ ->
        failwithf "%s: the audit succeeded, expected \"%s\"" name message ()
    | Error failure ->
        if not (String.equal failure.message message) then
          failwithf "%s: the audit failed with \"%s: %s\", expected \"%s\"" name
            failure.message failure.error message ()
  in
  match%map Auditor.check ~logger ~pool with
  | Ok _ ->
      failwithf "%s: the check succeeded, expected \"%s\"" name message ()
  | Error reason ->
      let prefix = sprintf "The audit failed: %s: " message in
      if not (String.is_prefix reason ~prefix) then
        failwithf "%s: the check failed with \"%s\", expected \"%s...\"" name
          reason prefix ()

(* [run] and [check] must both succeed and report [expected] as the first
   missing parent. *)
let expect_missing ~name ~pool (expected : Auditor.missing_parent option) =
  let show = function
    | None ->
        "none"
    | Some { Auditor.hash; height } ->
        sprintf "%s at height %d" hash height
  in
  let%bind () =
    match%map Audit.run ~logger ~pool with
    | Ok report ->
        let found = Auditor.first_missing_parent report.missing_blocks in
        if not (Option.equal Auditor.equal_missing_parent found expected) then
          failwithf "%s: the audit found %s, expected %s" name (show found)
            (show expected) ()
    | Error failure ->
        failwithf "%s: the audit failed: %s: %s" name failure.message
          failure.error ()
  in
  match%map Auditor.check ~logger ~pool with
  | Ok found ->
      if not (Option.equal Auditor.equal_missing_parent found expected) then
        failwithf "%s: the check found %s, expected %s" name (show found)
          (show expected) ()
  | Error reason ->
      failwithf "%s: the check failed: %s" name reason ()

let no_canonical_genesis = "Error getting genesis or first fork block height"

let test_case (test_data : t) =
  (* The server of the database that the fixture made. *)
  let postgres_uri =
    Uri.with_path (Uri.of_string test_data.config.postgres_uri) ""
    |> Uri.to_string
  in
  let connection = Psql.Conn_str postgres_uri in
  let%bind no_schema =
    Psql.create_empty_random_db ~connection ~prefix:"audit_no_schema"
  in
  let%bind () =
    expect_failure ~name:"no schema"
      ~pool:(connect (postgres_uri ^ "/" ^ no_schema))
      ~message:"Error getting missing blocks"
  in
  (* The fixture made this database with the schema and no block. *)
  let%bind () =
    expect_failure ~name:"no block"
      ~pool:(connect test_data.config.postgres_uri)
      ~message:no_canonical_genesis
  in
  let%bind sample =
    Psql.create_empty_random_db ~connection ~prefix:"audit_sample"
  in
  let%bind _ =
    Psql.run_script ~connection ~db:sample
      (Network_data.init_script_path test_data.network_data)
  in
  let uri = postgres_uri ^ "/" ^ sample in
  let pool = connect uri in
  let%bind () = expect_missing ~name:"sample archive" ~pool None in
  (* Remove the link of one block in the middle of the chain to its parent,
     as if the archive lacked that parent. *)
  let%bind height =
    Psql.run_command ~connection:(Psql.Conn_str uri)
      "SELECT (MIN(height) + MAX(height)) / 2 FROM blocks"
    >>| Or_error.ok_exn >>| Int.of_string
  in
  let%bind parent_hash =
    Psql.run_command ~connection:(Psql.Conn_str uri)
      (sprintf
         "SELECT parent_hash FROM blocks WHERE height = %d AND chain_status = \
          'canonical'"
         height )
    >>| Or_error.ok_exn
  in
  let%bind () =
    sql ~uri
      (sprintf
         "UPDATE blocks SET parent_id = NULL WHERE height = %d AND \
          chain_status = 'canonical'"
         height )
  in
  let%bind () =
    expect_missing ~name:"one parent link removed" ~pool
      (Some { hash = parent_hash; height = height - 1 })
  in
  let%bind () = sql ~uri "UPDATE blocks SET chain_status = 'pending'" in
  let%map () =
    expect_failure ~name:"no canonical block" ~pool
      ~message:no_canonical_genesis
  in
  Mina_automation_fixture.Intf.Passed
