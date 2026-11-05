(* Tests of the guardian's settings, of the reading of a child's log, of the
   block download with [Mock_bucket] and of the recovery with [Fake_app]. *)

open Core
open Async
module Config = Missing_blocks_guardian_lib.Config
module App_log = Missing_blocks_guardian_lib.App_log
module Download = Missing_blocks_guardian_lib.Download
module Subprocess = Missing_blocks_guardian_lib.Subprocess
module Archive_blocks = Missing_blocks_guardian_lib.Archive_blocks
module Auditor = Missing_blocks_guardian_lib.Auditor
module Bucket = Missing_blocks_guardian_lib.Bucket
module Recovery = Missing_blocks_guardian_lib.Recovery
module Cli = Missing_blocks_guardian_lib.Cli

let env pairs name = List.Assoc.find pairs ~equal:String.equal name

let no_env = env []

(* [result] has exactly one problem per entry of [mentioning], in order, and
   each problem contains its entry. *)
let expect_problems ~mentioning = function
  | Ok _ ->
      Alcotest.fail "expected problems, got a value"
  | Error problems ->
      Alcotest.(check int)
        (sprintf "number of problems in %s" (String.concat ~sep:" | " problems))
        (List.length mentioning) (List.length problems) ;
      List.iter2_exn mentioning problems ~f:(fun needle problem ->
          Alcotest.(check bool)
            (sprintf "%S mentions %S" problem needle)
            true
            (String.is_substring problem ~substring:needle) )

let expect_ok = function
  | Ok value ->
      value
  | Error problems ->
      Alcotest.fail (String.concat ~sep:" | " problems)

let test_flag_wins_over_env () =
  Alcotest.(check int)
    "flag" 7
    (expect_ok (Config.interval ~env:(env [ ("TIMEOUT", "5") ]) (Some "7")))

let test_env_fallback_and_default () =
  Alcotest.(check int)
    "env" 5
    (expect_ok (Config.interval ~env:(env [ ("TIMEOUT", "5") ]) None)) ;
  Alcotest.(check int)
    "default" Config.Default.interval
    (expect_ok (Config.interval ~env:no_env None))

let test_invalid_values_name_their_source () =
  expect_problems
    ~mentioning:[ "TIMEOUT=abc: expected a positive integer" ]
    (Config.interval ~env:(env [ ("TIMEOUT", "abc") ]) None) ;
  expect_problems
    ~mentioning:[ "--interval 0: expected a positive integer" ]
    (Config.interval ~env:no_env (Some "0"))

let test_archive_uri_from_env () =
  let uri =
    expect_ok
      (Config.archive_uri
         ~env:
           (env
              [ ("DB_USERNAME", "mina")
              ; ("PGPASSWORD", "p@ss/w:rd")
              ; ("DB_HOST", "postgres")
              ; ("DB_PORT", "5432")
              ; ("DB_NAME", "archive")
              ] )
         None )
  in
  Alcotest.(check (option string))
    "password decodes" (Some "p@ss/w:rd") (Uri.password uri) ;
  Alcotest.(check string)
    "uri" "postgres://mina:p%40ss%2Fw%3Ard@postgres:5432/archive"
    (Uri.to_string uri) ;
  let redacted = Config.redact uri in
  Alcotest.(check bool)
    "redacted has no password" false
    (String.is_substring redacted ~substring:"p%40ss") ;
  Alcotest.(check string)
    "redacted" "postgres://mina:<hidden>@postgres:5432/archive" redacted

let test_archive_uri_env_problems () =
  expect_problems
    ~mentioning:
      [ "missing --archive-uri: pass the flag or set the environment variables \
         DB_USERNAME, PGPASSWORD, DB_HOST, DB_PORT, DB_NAME"
      ]
    (Config.archive_uri ~env:no_env None) ;
  expect_problems
    ~mentioning:[ "(not set: DB_HOST, DB_PORT)" ]
    (Config.archive_uri
       ~env:
         (env
            [ ("DB_USERNAME", "mina")
            ; ("PGPASSWORD", "x")
            ; ("DB_NAME", "archive")
            ] )
       None ) ;
  expect_problems
    ~mentioning:[ "DB_PORT=abc: expected a port number" ]
    (Config.archive_uri
       ~env:
         (env
            [ ("DB_USERNAME", "mina")
            ; ("PGPASSWORD", "x")
            ; ("DB_HOST", "h")
            ; ("DB_PORT", "abc")
            ; ("DB_NAME", "archive")
            ] )
       None )

let test_archive_uri_flag_problem_hides_password () =
  match
    Config.archive_uri ~env:no_env (Some "mysql://mina:secret@h:3306/archive")
  with
  | Ok _ ->
      Alcotest.fail "expected a problem"
  | Error problems ->
      let text = String.concat problems in
      Alcotest.(check bool)
        "mentions postgres" true
        (String.is_substring text ~substring:"expected a postgres:// URI") ;
      Alcotest.(check bool)
        "hides the password" false
        (String.is_substring text ~substring:"secret") ;
      Alcotest.(check bool)
        "shows <hidden>" true
        (String.is_substring text ~substring:"<hidden>")

let test_gs_url_hint () =
  expect_problems
    ~mentioning:[ "https://storage.googleapis.com/<bucket>" ]
    (Config.blocks ~env:no_env ~url:(Some "gs://mina_network_block_data")
       ~network:(Some "mainnet") ~format:None ~archive_blocks:None )

let test_blocks_url () =
  let blocks ~url =
    Config.blocks ~env:no_env ~url:(Some url) ~network:(Some "mainnet")
      ~format:None ~archive_blocks:None
  in
  Alcotest.(check string)
    "trailing slash removed" "https://bucket.example/blocks"
    (expect_ok (blocks ~url:"https://bucket.example/blocks/")).url ;
  Alcotest.(check string)
    "file url" "file:///tmp/blocks"
    (expect_ok (blocks ~url:"file:///tmp/blocks")).url ;
  expect_problems
    ~mentioning:[ "--precomputed-blocks-url ftp://x: expected an http" ]
    (blocks ~url:"ftp://x") ;
  expect_problems
    ~mentioning:[ "expected a host in the URL" ]
    (blocks ~url:"http:///blocks")

let test_blocks_problems_reported_together () =
  expect_problems
    ~mentioning:
      [ "PRECOMPUTED_BLOCKS_URL=ftp://x"
      ; "--network a/b: expected a name without spaces or slashes"
      ; "BLOCKS_FORMAT=json: expected precomputed or extensional"
      ]
    (Config.blocks
       ~env:
         (env
            [ ("PRECOMPUTED_BLOCKS_URL", "ftp://x"); ("BLOCKS_FORMAT", "json") ] )
       ~url:None ~network:(Some "a/b") ~format:None ~archive_blocks:None )

let test_both_collects_problems () =
  expect_problems
    ~mentioning:[ "missing --archive-uri"; "missing --precomputed-blocks-url" ]
    (Config.both
       (Config.archive ~env:no_env ~uri:None ~auditor:None)
       (Config.blocks ~env:no_env ~url:None ~network:(Some "mainnet")
          ~format:None ~archive_blocks:None ) )

let test_app_log () =
  let output =
    String.concat ~sep:"\n"
      [ Fake_app.message ~level:"Info" ~text:"Querying missing blocks"
          ~metadata:"{}"
      ; "not a log line"
      ; Fake_app.message ~level:"Error" ~text:"Error getting missing blocks"
          ~metadata:{|{"error":"Failed to connect"}|}
      ; ""
      ]
  in
  let messages, other_lines = App_log.parse output in
  Alcotest.(check int) "messages" 2 (List.length messages) ;
  Alcotest.(check (list string)) "other lines" [ "not a log line" ] other_lines ;
  match App_log.first_error messages with
  | None ->
      Alcotest.fail "expected an error"
  | Some error ->
      Alcotest.(check string)
        "describe" "Error getting missing blocks: Failed to connect"
        (App_log.describe error) ;
      Alcotest.(check bool)
        "no error among info messages" true
        (Option.is_none (App_log.first_error [ List.hd_exn messages ]))

(* Runs the flags of [param] on [argv] and returns what they map to. *)
let parse_flags param argv =
  let result = ref None in
  Command.run ~argv:("guardian" :: argv)
    (Command.basic ~summary:"test"
       (let%map_open.Command value = param in
        fun () -> result := Some value ) ) ;
  Option.value_exn !result

(* The flags reach Config: a flag wins over the environment, and a flag that
   is not given falls back to it. *)
let test_cli_flags () =
  let env = env [ ("DB_HOST", "ignored"); ("MINA_NETWORK", "devnet") ] in
  let archive =
    parse_flags Cli.archive
      [ "--archive-uri"; "postgres://mina:pw@db:5432/archive" ]
  in
  let archive = expect_ok (archive ~env) in
  Alcotest.(check string)
    "archive uri from the flag" "postgres://mina:pw@db:5432/archive"
    (Uri.to_string archive.uri) ;
  Alcotest.(check string)
    "auditor default" Config.Default.auditor archive.auditor ;
  let blocks =
    parse_flags Cli.blocks
      [ "--precomputed-blocks-url"
      ; "https://bucket.example/blocks/"
      ; "--block-format"
      ; "extensional"
      ]
  in
  let blocks = expect_ok (blocks ~env) in
  Alcotest.(check string)
    "url without the trailing slash" "https://bucket.example/blocks" blocks.url ;
  Alcotest.(check string) "network from the environment" "devnet" blocks.network ;
  Alcotest.(check string)
    "format from the flag" "extensional"
    (Config.Block_format.to_string blocks.format) ;
  let interval = parse_flags Cli.interval [ "--interval"; "30" ] in
  Alcotest.(check int) "interval" 30 (expect_ok (interval ~env)) ;
  let interval = parse_flags Cli.interval [] in
  Alcotest.(check int)
    "interval default" Config.Default.interval
    (expect_ok (interval ~env)) ;
  expect_problems ~mentioning:[ "--interval" ]
    (parse_flags Cli.interval [ "--interval"; "soon" ] ~env)

(* A program that writes a secret to stderr and exits with 2: the secret is
   hidden and the failure text has the stderr. *)
let test_subprocess_failure () =
  let logger = Logger.null () in
  let output =
    Thread_safe.block_on_async_exn (fun () ->
        Subprocess.run ~logger ~secrets:[ "s3cret" ] ~prog:"sh"
          ~args:[ "-c"; "echo 'cannot open s3cret' >&2; exit 2" ]
          () )
    |> Or_error.ok_exn
  in
  Alcotest.(check string) "stderr hidden" "cannot open <hidden>\n" output.stderr ;
  Alcotest.(check string)
    "wrote" " and wrote: cannot open <hidden>" (Subprocess.wrote output) ;
  Alcotest.(check bool)
    "exited with 2" true
    ( match output.exit_status with
    | Error (`Exit_non_zero 2) ->
        true
    | _ ->
        false ) ;
  let quiet =
    Thread_safe.block_on_async_exn (fun () ->
        Subprocess.run ~logger ~prog:"true" ~args:[] () )
    |> Or_error.ok_exn
  in
  Alcotest.(check string) "nothing written" "" (Subprocess.wrote quiet)

let test_bucket_block_url () =
  let file =
    Bucket.block_file ~network:"mainnet" ~height:5 ~state_hash:"3NKabc"
  in
  Alcotest.(check string) "file" "mainnet-5-3NKabc.json" file ;
  Alcotest.(check string)
    "url" "https://b.example/mainnet-5-3NKabc.json"
    (Bucket.block_url ~url:"https://b.example" ~file)

let test_bucket_listing () =
  let check name ~url ~uri ~key_prefix ~url_is_bucket =
    let listing = Bucket.listing ~url ~network:"mainnet" in
    Alcotest.(check string) (name ^ " uri") uri (Uri.to_string listing.uri) ;
    Alcotest.(check string) (name ^ " prefix") key_prefix listing.key_prefix ;
    Alcotest.(check bool) (name ^ " bucket") url_is_bucket listing.url_is_bucket
  in
  check "host" ~url:"https://b.example"
    ~uri:"https://b.example/?prefix=mainnet-&max-keys=1" ~key_prefix:"mainnet-"
    ~url_is_bucket:true ;
  check "bucket" ~url:"https://h.example/b"
    ~uri:"https://h.example/b/?prefix=mainnet-&max-keys=1"
    ~key_prefix:"mainnet-" ~url_is_bucket:true ;
  check "path" ~url:"https://h.example/b/x/y"
    ~uri:"https://h.example/b/?prefix=x/y/mainnet-&max-keys=1"
    ~key_prefix:"x/y/mainnet-" ~url_is_bucket:false

let test_download_not_found () =
  Mock_bucket.with_server (fun ~url ~dir ->
      let file = dir ^/ "mainnet-4-3NKmissing.json" in
      match%bind
        Download.fetch ~url:(url ^ "/mainnet-4-3NKmissing.json") ~file
      with
      | Ok () ->
          Alcotest.fail "expected an error"
      | Error err ->
          Alcotest.(check bool)
            "names the status" true
            (String.is_substring (Error.to_string_hum err)
               ~substring:"HTTP 404 Not Found" ) ;
          let%map exists = Sys.file_exists_exn file in
          Alcotest.(check bool) "no file saved" false exists )

let expect_error_with ~substring = function
  | Ok _ ->
      Alcotest.failf "expected an error with %S" substring
  | Error text ->
      Alcotest.(check bool)
        (sprintf "%S mentions %S" text substring)
        true
        (String.is_substring text ~substring)

let probe ~url ~network =
  Deferred.map
    (Download.probe ~url ~network)
    ~f:(Result.map_error ~f:Error.to_string_hum)

let check_ok name result = Alcotest.(check bool) name true (Result.is_ok result)

(* A listing decides when there is one. Other answers cannot say that the
   files are absent, and only a 404 of the bucket itself is an error. *)
let test_probe () =
  Mock_bucket.with_server (fun ~url ~dir ->
      let bucket = url ^ "/listed" in
      let%bind listed = probe ~url:bucket ~network:"mainnet" in
      check_ok "the list has the network" listed ;
      let%bind listed = probe ~url:(bucket ^ "/sub") ~network:"mainnet" in
      check_ok "the list has the network under a path" listed ;
      let%bind no_files = probe ~url:bucket ~network:"devnet" in
      expect_error_with ~substring:"no file that starts with devnet-" no_files ;
      let%bind no_files = probe ~url:(bucket ^ "/other") ~network:"mainnet" in
      expect_error_with ~substring:"no file that starts with other/mainnet-"
        no_files ;
      let%bind private_bucket = probe ~url ~network:"mainnet" in
      check_ok "403 is a private bucket" private_bucket ;
      let%bind plain = probe ~url:(url ^ "/plain") ~network:"mainnet" in
      check_ok "a page is not a list" plain ;
      let%bind missing =
        probe ~url:(url ^ "/no-such-bucket") ~network:"mainnet"
      in
      expect_error_with ~substring:"HTTP 404 Not Found, nothing at" missing ;
      let%bind path = probe ~url:(url ^ "/a/b") ~network:"mainnet" in
      check_ok "404 below a path says nothing" path ;
      let%bind directory = probe ~url:("file://" ^ dir) ~network:"mainnet" in
      check_ok "directory" directory ;
      let%bind no_directory =
        probe ~url:("file://" ^ dir ^ "/none") ~network:"mainnet"
      in
      expect_error_with ~substring:"is not a directory" no_directory ;
      let%map unreachable =
        probe ~url:"http://127.0.0.1:1" ~network:"mainnet"
      in
      Alcotest.(check bool) "unreachable" true (Result.is_error unreachable) )

let test_download_ok () =
  Mock_bucket.with_server (fun ~url ~dir ->
      let file = dir ^/ "mainnet-5-3NKabc.json" in
      match%bind Download.fetch ~url:(url ^ Mock_bucket.block_path) ~file with
      | Error err ->
          Alcotest.fail (Error.to_string_hum err)
      | Ok () ->
          let%map contents = Reader.file_contents file in
          Alcotest.(check string) "saved body" Mock_bucket.block_body contents )

let test_download_missing_file_url () =
  Mock_bucket.with_server (fun ~url:_ ~dir ->
      let file = dir ^/ "out.json" in
      match%map
        Download.fetch ~url:("file://" ^ dir ^ "/absent.json") ~file
      with
      | Ok () ->
          Alcotest.fail "expected an error"
      | Error _ ->
          () )

let archive_uri = Uri.of_string "postgres://mina:secret@db:5432/archive"

let check_auditor ~prog =
  Auditor.check ~logger:(Logger.null ()) ~prog ~archive_uri

let archive ~auditor : Config.archive = { uri = archive_uri; auditor }

let blocks ~dir ~archive_blocks : Config.blocks =
  { url = "file://" ^ dir
  ; network = "mainnet"
  ; format = Config.Default.format
  ; archive_blocks
  }

let test_auditor_missing_blocks () =
  Fake_app.with_dir (fun ~dir ->
      (* The auditor exits with 1 whenever blocks are missing: that is a
         result, not a failure. *)
      let%bind prog =
        Fake_app.printing ~dir ~name:"auditor"
          ~lines:
            [ Fake_app.info_line
            ; Fake_app.parent_lacking ~height:4 ~hash:"3NKfour"
            ]
          ~ending:"exit 1"
      in
      let%map result = check_auditor ~prog in
      match result with
      | Ok (Some parent) ->
          Alcotest.(check string) "hash" "3NKfour" parent.hash ;
          Alcotest.(check int) "height" 4 parent.height
      | Ok None ->
          Alcotest.fail "expected a missing parent"
      | Error text ->
          Alcotest.fail text )

let test_auditor_healthy () =
  Fake_app.with_dir (fun ~dir ->
      let%bind prog =
        Fake_app.printing ~dir ~name:"auditor" ~lines:[ Fake_app.info_line ]
          ~ending:"exit 0"
      in
      let%map result = check_auditor ~prog in
      Alcotest.(check bool)
        "no missing parent" true
        (match result with Ok None -> true | _ -> false) )

let test_auditor_error_line () =
  Fake_app.with_dir (fun ~dir ->
      let%bind prog =
        Fake_app.printing ~dir ~name:"auditor"
          ~lines:
            [ Fake_app.error_line
            ; Fake_app.parent_lacking ~height:4 ~hash:"3NKfour"
            ]
          ~ending:"exit 1"
      in
      let%map result = check_auditor ~prog in
      expect_error_with
        ~substring:"Error getting missing blocks: Failed to connect" result )

let test_auditor_no_log () =
  Fake_app.with_dir (fun ~dir ->
      let%bind prog = Fake_app.write_program ~dir ~name:"auditor" "exit 0" in
      let%map result = check_auditor ~prog in
      expect_error_with ~substring:"it wrote no log message" result )

let test_auditor_signal () =
  Fake_app.with_dir (fun ~dir ->
      let%bind prog =
        Fake_app.printing ~dir ~name:"auditor" ~lines:[ Fake_app.info_line ]
          ~ending:"echo gone >&2\nkill -KILL $$"
      in
      let%map result = check_auditor ~prog in
      expect_error_with ~substring:"it was killed by signal" result ;
      expect_error_with ~substring:"and wrote: gone" result )

let test_auditor_not_found () =
  Fake_app.with_dir (fun ~dir ->
      let%map result = check_auditor ~prog:(dir ^/ "absent") in
      expect_error_with ~substring:"failed: " result )

let block_name = "mainnet-5-3NKfive.json"

let block_at_five : Auditor.missing_parent = { hash = "3NKfive"; height = 5 }

(* Runs [populate] on a block file in the working directory. The file must
   be removed in every case. *)
let populate ~dir ~archive_blocks =
  let%bind () = Writer.save block_name ~contents:Mock_bucket.block_body in
  let%bind result =
    Recovery.populate ~logger:(Logger.null ())
      (archive ~auditor:"unused")
      (blocks ~dir ~archive_blocks)
      block_name
  in
  let%map exists = Sys.file_exists_exn block_name in
  Alcotest.(check bool) "file removed" false exists ;
  result

(* The flags of the format and of the database, then the file. *)
let test_archive_blocks_arguments () =
  Fake_app.with_dir (fun ~dir ->
      let%bind prog =
        Fake_app.printing ~dir ~name:"archive-blocks"
          ~lines:[ Fake_app.info_line ]
          ~ending:(sprintf "echo \"$*\" > %s/arguments" dir)
      in
      let%bind result =
        Archive_blocks.add ~logger:(Logger.null ()) ~prog
          ~format:Config.Block_format.Extensional ~archive_uri "block.json"
      in
      check_ok "added" result ;
      let%map arguments = Reader.file_lines (dir ^/ "arguments") in
      Alcotest.(check (list string))
        "arguments"
        [ "--extensional --archive-uri " ^ Uri.to_string archive_uri
          ^ " block.json"
        ]
        arguments )

let test_populate_ok () =
  Fake_app.with_dir (fun ~dir ->
      let%bind archive_blocks =
        Fake_app.printing ~dir ~name:"archive-blocks"
          ~lines:[ Fake_app.info_line ] ~ending:"exit 0"
      in
      let%map result = populate ~dir ~archive_blocks in
      check_ok "added" result )

let test_populate_error_line () =
  Fake_app.with_dir (fun ~dir ->
      (* mina-archive-blocks exits with 0 when it cannot add a block. *)
      let%bind archive_blocks =
        Fake_app.printing ~dir ~name:"archive-blocks"
          ~lines:[ Fake_app.error_line ] ~ending:"exit 0"
      in
      let%map result = populate ~dir ~archive_blocks in
      expect_error_with ~substring:"Failed to connect" result ;
      expect_error_with ~substring:"The database remains unhealthy" result )

let test_populate_exit_code () =
  Fake_app.with_dir (fun ~dir ->
      let%bind archive_blocks =
        Fake_app.printing ~dir ~name:"archive-blocks"
          ~lines:[ Fake_app.info_line ] ~ending:"echo bad flag >&2\nexit 2"
      in
      let%map result = populate ~dir ~archive_blocks in
      expect_error_with ~substring:"it exited with 2 and wrote: bad flag" result )

let test_populate_signal () =
  Fake_app.with_dir (fun ~dir ->
      let%bind archive_blocks =
        Fake_app.printing ~dir ~name:"archive-blocks" ~lines:[]
          ~ending:"kill -KILL $$"
      in
      let%map result = populate ~dir ~archive_blocks in
      expect_error_with ~substring:"it was killed by signal" result )

let save_block ~dir ~height ~hash =
  Writer.save
    (dir ^/ sprintf "mainnet-%d-%s.json" height hash)
    ~contents:Mock_bucket.block_body

(* A fake mina-archive-blocks that records the names of its files in
   [dir]/imported, so that a test can see the order of the imports. *)
let recording_archive_blocks ~dir =
  let%bind () =
    Writer.save (dir ^/ "line") ~contents:(Fake_app.info_line ^ "\n")
  in
  Fake_app.write_program ~dir ~name:"archive-blocks"
    (sprintf "for last; do :; done\necho \"$last\" >> %s/imported\ncat %s/line"
       dir dir )

let restore ~dir ~auditor ~archive_blocks =
  Recovery.restore ~logger:(Logger.null ()) (archive ~auditor)
    (blocks ~dir ~archive_blocks)
    block_at_five

let test_restore_follows_parents () =
  Fake_app.with_dir (fun ~dir ->
      let%bind () = save_block ~dir ~height:5 ~hash:"3NKfive" in
      let%bind () = save_block ~dir ~height:4 ~hash:"3NKfour" in
      let%bind auditor =
        Fake_app.printing_in_turn ~dir ~name:"auditor"
          ~runs:
            [ [ Fake_app.parent_lacking ~height:4 ~hash:"3NKfour" ]
            ; [ Fake_app.info_line ]
            ]
      in
      let%bind archive_blocks = recording_archive_blocks ~dir in
      let%bind result = restore ~dir ~auditor ~archive_blocks in
      check_ok "restored" result ;
      let%map imported = Reader.file_lines (dir ^/ "imported") in
      Alcotest.(check (list string))
        "imports in order"
        [ block_name; "mainnet-4-3NKfour.json" ]
        imported )

let test_restore_no_progress () =
  Fake_app.with_dir (fun ~dir ->
      let%bind () = save_block ~dir ~height:5 ~hash:"3NKfive" in
      let%bind auditor =
        Fake_app.printing ~dir ~name:"auditor"
          ~lines:[ Fake_app.parent_lacking ~height:5 ~hash:"3NKfive" ]
          ~ending:"exit 1"
      in
      let%bind archive_blocks = recording_archive_blocks ~dir in
      let%bind result = restore ~dir ~auditor ~archive_blocks in
      expect_error_with ~substring:"still lacks block 3NKfive at height 5"
        result ;
      let%map imported = Reader.file_lines (dir ^/ "imported") in
      Alcotest.(check (list string)) "one import" [ block_name ] imported )

let test_restore_block_not_in_bucket () =
  Fake_app.with_dir (fun ~dir ->
      let%bind auditor =
        Fake_app.printing ~dir ~name:"auditor" ~lines:[ Fake_app.info_line ]
          ~ending:"exit 0"
      in
      let%bind archive_blocks = recording_archive_blocks ~dir in
      let%map result = restore ~dir ~auditor ~archive_blocks in
      expect_error_with ~substring:"Could not download the block at height 5"
        result )

let test_restore_auditor_fails () =
  Fake_app.with_dir (fun ~dir ->
      let%bind () = save_block ~dir ~height:5 ~hash:"3NKfive" in
      let%bind auditor =
        Fake_app.printing ~dir ~name:"auditor" ~lines:[ Fake_app.error_line ]
          ~ending:"exit 1"
      in
      let%bind archive_blocks = recording_archive_blocks ~dir in
      let%map result = restore ~dir ~auditor ~archive_blocks in
      expect_error_with ~substring:"Failed to connect" result )

let () =
  Alcotest.run "missing_blocks_guardian"
    [ ( "config"
      , [ Alcotest.test_case "flag wins over env" `Quick test_flag_wins_over_env
        ; Alcotest.test_case "env fallback and default" `Quick
            test_env_fallback_and_default
        ; Alcotest.test_case "invalid values name their source" `Quick
            test_invalid_values_name_their_source
        ; Alcotest.test_case "archive uri from env" `Quick
            test_archive_uri_from_env
        ; Alcotest.test_case "archive uri env problems" `Quick
            test_archive_uri_env_problems
        ; Alcotest.test_case "archive uri flag problem hides password" `Quick
            test_archive_uri_flag_problem_hides_password
        ; Alcotest.test_case "blocks url" `Quick test_blocks_url
        ; Alcotest.test_case "gs url hint" `Quick test_gs_url_hint
        ; Alcotest.test_case "blocks problems reported together" `Quick
            test_blocks_problems_reported_together
        ; Alcotest.test_case "both collects problems" `Quick
            test_both_collects_problems
        ] )
    ; ("app_log", [ Alcotest.test_case "parse and errors" `Quick test_app_log ])
    ; ("cli", [ Alcotest.test_case "flags reach config" `Quick test_cli_flags ])
    ; ( "subprocess"
      , [ Alcotest.test_case "failure text has stderr, secrets hidden" `Quick
            test_subprocess_failure
        ] )
    ; ( "bucket"
      , [ Alcotest.test_case "block url" `Quick test_bucket_block_url
        ; Alcotest.test_case "listing" `Quick test_bucket_listing
        ] )
    ; ( "download"
      , [ Alcotest.test_case "not found is an error" `Quick
            test_download_not_found
        ; Alcotest.test_case "success saves the body" `Quick test_download_ok
        ; Alcotest.test_case "missing file url is an error" `Quick
            test_download_missing_file_url
        ; Alcotest.test_case "probe of the bucket" `Quick test_probe
        ] )
    ; ( "auditor"
      , [ Alcotest.test_case "exit 1 with missing blocks is a result" `Quick
            test_auditor_missing_blocks
        ; Alcotest.test_case "healthy archive" `Quick test_auditor_healthy
        ; Alcotest.test_case "error line is a failure" `Quick
            test_auditor_error_line
        ; Alcotest.test_case "no log is a failure" `Quick test_auditor_no_log
        ; Alcotest.test_case "signal is a failure" `Quick test_auditor_signal
        ; Alcotest.test_case "program not found is a failure" `Quick
            test_auditor_not_found
        ] )
    ; ( "archive_blocks"
      , [ Alcotest.test_case "arguments" `Quick test_archive_blocks_arguments ]
      )
    ; ( "populate"
      , [ Alcotest.test_case "success" `Quick test_populate_ok
        ; Alcotest.test_case "error line with exit 0 is a failure" `Quick
            test_populate_error_line
        ; Alcotest.test_case "non-zero exit is a failure" `Quick
            test_populate_exit_code
        ; Alcotest.test_case "signal is a failure" `Quick test_populate_signal
        ] )
    ; ( "restore"
      , [ Alcotest.test_case "follows the missing parents" `Quick
            test_restore_follows_parents
        ; Alcotest.test_case "stops when nothing changes" `Quick
            test_restore_no_progress
        ; Alcotest.test_case "stops when the block is not in the bucket" `Quick
            test_restore_block_not_in_bucket
        ; Alcotest.test_case "stops when the auditor fails" `Quick
            test_restore_auditor_fails
        ] )
    ]
