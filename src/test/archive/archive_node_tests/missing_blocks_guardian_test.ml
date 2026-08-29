(** Component test for [mina-missing-blocks-guardian].

    An archive database is filled from the sample precomputed blocks with one
    block in the middle withheld, so exactly one block has no parent. The test
    then checks, against that real database:

    - [audit] reports the gap and sets bit 0 of its exit code;
    - a block source that answers 404 is refused, and nothing is written;
    - a block source that answers 200 with an error page is refused, and
      nothing is written;
    - a block source that really holds the block closes the gap;
    - [audit] is clean afterwards.

    The two refusal cases are the bug this app was written for. The bash
    guardian it replaces ran [curl -s], which reports success for a 404 and
    saves the bucket's error page as the block file; that file then reached
    [mina-archive-blocks] and failed there with a JSON parse error naming
    neither the URL nor the HTTP status. *)

open Async
open Core
open Mina_automation

let logger = Logger.create ()

(** A stand-in for the precomputed blocks bucket, so the test can choose what
    the guardian gets back for the block it asks for. *)
module Mock_bucket = struct
  type behaviour =
    | Not_found  (** what a bucket answers for a block it does not hold *)
    | Error_page
        (** 200 with an HTML body: the response [curl -s] used to save as a
            block file *)

  type t = { server : (Socket.Address.Inet.t, int) Cohttp_async.Server.t }

  let body_of = function
    | Not_found ->
        "<?xml version=\"1.0\" \
         encoding=\"UTF-8\"?><Error><Code>NoSuchKey</Code><Message>The \
         specified key does not exist.</Message></Error>"
    | Error_page ->
        "<!DOCTYPE html><html><head><title>Error 404 (Not \
         Found)</title></head><body><h1>404. That is an \
         error.</h1></body></html>"

  let status_of = function Not_found -> `Not_found | Error_page -> `OK

  let headers_of = function
    | Not_found ->
        Cohttp.Header.of_list [ ("Content-Type", "application/xml") ]
    | Error_page ->
        Cohttp.Header.of_list [ ("Content-Type", "text/html; charset=UTF-8") ]

  let start behaviour =
    let%map server =
      Cohttp_async.Server.create_expert
        ~on_handler_error:
          (`Call
             (fun _net exn ->
               [%log warn] "Mock bucket handler error: $error"
                 ~metadata:[ ("error", `String (Exn.to_string exn)) ] ) )
        Async.Tcp.Where_to_listen.of_port_chosen_by_os
        (fun ~body:_ _sock _req ->
          let%map response =
            Cohttp_async.Server.respond_string ~status:(status_of behaviour)
              ~headers:(headers_of behaviour) (body_of behaviour)
          in
          `Response response )
    in
    { server }

  let uri t =
    Uri.of_string
      (sprintf "http://127.0.0.1:%d/blocks"
         (Cohttp_async.Server.listening_on t.server) )

  let stop t = Cohttp_async.Server.close t.server
end

let count ~archive_uri ~what query =
  let connection = Psql.Conn_str archive_uri in
  match%map Psql.run_command ~connection query with
  | Ok result ->
      Int.of_string (String.strip result)
  | Error err ->
      failwithf "Failed to %s: %s" what (Error.to_string_hum err) ()

let block_count ~archive_uri =
  count ~archive_uri ~what:"count blocks" "SELECT COUNT(*) FROM blocks"

let unparented_count ~archive_uri =
  count ~archive_uri ~what:"count blocks with no parent"
    "SELECT COUNT(*) FROM blocks WHERE parent_id IS NULL"

let lowest_height ~archive_uri =
  count ~archive_uri ~what:"read the lowest block height"
    "SELECT MIN(height) FROM blocks"

let run_guardian ?min_height ~archive_uri ~precomputed_blocks ~run_mode () =
  Missing_blocks_guardian.run_capturing Missing_blocks_guardian.default
    ~config:
      { Missing_blocks_guardian.Config.archive_uri = Uri.of_string archive_uri
      ; precomputed_blocks
      ; network = "mainnet"
      ; run_mode
      ; block_format = `Precomputed
      ; min_height
      }

(* The guardian writes the Mina JSON log to stdout.  Search the whole output
   rather than one field, so the assertion does not depend on which log line
   carries the text. *)
let assert_output_mentions ~what output substring =
  if not (String.is_substring output ~substring) then
    failwithf "%s: expected the guardian output to mention %S.\nOutput:\n%s"
      what substring output ()

let assert_failed ~what (outcome : Missing_blocks_guardian.outcome) =
  if Int.equal outcome.exit_code 0 then
    failwithf "%s: expected the guardian to fail, but it exited 0.\nOutput:\n%s"
      what outcome.stdout ()

let assert_succeeded ~what (outcome : Missing_blocks_guardian.outcome) =
  if not (Int.equal outcome.exit_code 0) then
    failwithf
      "%s: expected the guardian to exit 0, but it exited %d.\nOutput:\n%s" what
      outcome.exit_code outcome.stdout ()

(** Point the guardian at a bucket that answers badly, and check that it
    refuses what it gets and leaves the archive alone. *)
let assert_refuses_bad_download ~archive_uri ~min_height ~behaviour
    ~expected_message ~what =
  let%bind bucket = Mock_bucket.start behaviour in
  let%bind blocks_before = block_count ~archive_uri in
  let%bind outcome =
    run_guardian ~min_height ~archive_uri
      ~precomputed_blocks:(Mock_bucket.uri bucket) ~run_mode:Run ()
  in
  let%bind () = Mock_bucket.stop bucket in
  assert_failed ~what outcome ;
  assert_output_mentions ~what outcome.stdout expected_message ;
  let%map blocks_after = block_count ~archive_uri in
  if not (Int.equal blocks_before blocks_after) then
    failwithf
      "%s: the guardian must write nothing when it refuses the download, but \
       the block count went from %d to %d"
      what blocks_before blocks_after ()

type t = Mina_automation_fixture.Archive.before_bootstrap

let test_case (test_data : t) =
  let open Deferred.Let_syntax in
  let archive_uri = test_data.config.postgres_uri in
  let%bind precomputed_blocks =
    Common.unpack_precomputed_blocks test_data.network_data
      ~temp_dir:test_data.temp_dir
  in
  (* The unpacked blocks are named <network>-<height>-<state hash>.json, which
     is the layout the guardian looks for, so the temp dir doubles as a block
     source that really holds every block. *)
  let good_source = Uri.make ~scheme:"file" ~path:test_data.temp_dir () in
  let total = List.length precomputed_blocks in
  if total < 3 then
    failwithf "Need at least 3 sample blocks to leave a hole, got %d" total () ;
  (* Withhold one block from the middle, so exactly one block has no parent.
     The first and the last are left in place: a gap at either end is not the
     kind of gap the guardian closes. *)
  let withheld_index = total / 2 in
  let withheld = List.nth_exn precomputed_blocks withheld_index in
  [%log info] "Withholding $block so that its child has no parent"
    ~metadata:[ ("block", `String withheld) ] ;
  let kept =
    List.filteri precomputed_blocks ~f:(fun i _ ->
        not (Int.equal i withheld_index) )
  in
  let%bind (_ : string) =
    Archive_blocks.run Archive_blocks.default ~blocks:kept ~archive_uri
      ~format:Precomputed
  in
  let%bind archived = block_count ~archive_uri in
  if not (Int.equal archived (List.length kept)) then
    failwithf "Expected %d blocks in the archive, found %d" (List.length kept)
      archived () ;
  (* The sample archive does not reach back to a genesis block, so its lowest
     block will always have no parent and its own parent can never be fetched.
     --min-height stops the walk there instead of asking the block source for
     blocks that cannot exist. *)
  let%bind min_height = lowest_height ~archive_uri in
  let%bind unparented = unparented_count ~archive_uri in
  (* The lowest block in the sample has no parent by construction, and so does
     the child of the block we withheld. *)
  if not (Int.equal unparented 2) then
    failwithf
      "Expected two blocks with no parent after withholding %s (the lowest \
       block and the child of the hole), found %d"
      withheld unparented () ;

  (* 1. The audit must report the gap. *)
  let%bind audit =
    run_guardian ~min_height ~archive_uri ~precomputed_blocks:good_source
      ~run_mode:Audit ()
  in
  let what = "audit of an archive with a gap" in
  assert_failed ~what audit ;
  if not (Int.equal (audit.exit_code land 1) 1) then
    failwithf
      "%s: bit 0 of the exit code must be set when a block has no parent, but \
       the exit code was %d"
      what audit.exit_code () ;
  assert_output_mentions ~what audit.stdout "Block has no parent in archive db" ;

  (* 2. A bucket that does not hold the block must not be ingested. *)
  let%bind () =
    assert_refuses_bad_download ~archive_uri ~min_height
      ~behaviour:Mock_bucket.Not_found ~expected_message:"returned 404"
      ~what:"single-run against a bucket that answers 404"
  in

  (* 3. Neither must an error page served with a 200. *)
  let%bind () =
    assert_refuses_bad_download ~archive_uri ~min_height
      ~behaviour:Mock_bucket.Error_page ~expected_message:"is not valid JSON"
      ~what:"single-run against a bucket that answers 200 with an error page"
  in

  (* 4. A source that really holds the block closes the gap. *)
  let%bind repair =
    run_guardian ~min_height ~archive_uri ~precomputed_blocks:good_source
      ~run_mode:Run ()
  in
  let what = "single-run against a block source that holds the block" in
  assert_succeeded ~what repair ;
  assert_output_mentions ~what repair.stdout "Added block" ;
  let%bind blocks_after = block_count ~archive_uri in
  if not (Int.equal blocks_after total) then
    failwithf
      "%s: expected the archive to hold all %d blocks after the repair, but it \
       holds %d"
      what total blocks_after () ;
  let%bind unparented = unparented_count ~archive_uri in
  if not (Int.equal unparented 1) then
    failwithf
      "%s: expected only the lowest block to have no parent after the repair, \
       found %d such blocks"
      what unparented () ;

  (* 5. And the audit is clean.  The sample archive does not reach back to a
     genesis block, so --min-height is what makes a clean result reachable at
     all: it tells the guardian where this archive is meant to start, and the
     lowest block is then the bottom of the archive rather than a gap. *)
  let%bind final_audit =
    run_guardian ~min_height ~archive_uri ~precomputed_blocks:good_source
      ~run_mode:Audit ()
  in
  let what = "audit after the repair" in
  assert_succeeded ~what final_audit ;
  assert_output_mentions ~what final_audit.stdout
    "There are no missing blocks in the archive db" ;

  (* 6. Without --min-height the same archive is not clean, because nothing
     says where it is supposed to start: bit 4 reports that it reaches no
     genesis block. *)
  let%map audit_without_floor =
    run_guardian ~archive_uri ~precomputed_blocks:good_source ~run_mode:Audit ()
  in
  let what = "audit without --min-height" in
  if not (Int.equal (audit_without_floor.exit_code land 16) 16) then
    failwithf
      "%s: bit 4 of the exit code must be set when the archive reaches no \
       genesis block and no floor was given, but the exit code was %d.\n\
       Output:\n\
       %s"
      what audit_without_floor.exit_code audit_without_floor.stdout () ;
  Mina_automation_fixture.Intf.Passed
