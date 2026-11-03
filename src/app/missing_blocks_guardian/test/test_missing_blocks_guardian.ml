(* Tests of the guardian's settings, of the reading of a child's log and of
   the block download. *)

open Core
open Async
module Config = Missing_blocks_guardian_lib.Config
module App_log = Missing_blocks_guardian_lib.App_log
module Download = Missing_blocks_guardian_lib.Download
module Subprocess = Missing_blocks_guardian_lib.Subprocess
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

let message ~level ~text ~metadata =
  sprintf
    {|{"timestamp":"2026-11-02 10:00:00.000000Z","level":"%s","source":{"module":"x","location":"y"},"message":"%s","metadata":%s}|}
    level text metadata

let test_app_log () =
  let output =
    String.concat ~sep:"\n"
      [ message ~level:"Info" ~text:"Querying missing blocks" ~metadata:"{}"
      ; "not a log line"
      ; message ~level:"Error" ~text:"Error getting missing blocks"
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

let block_path = "/mainnet-5-3NKabc.json"

let block_body = {|{"block":"content"}|}

let not_found_body =
  {|<?xml version='1.0' encoding='UTF-8'?><Error><Code>NoSuchKey</Code></Error>|}

(* Serves [block_path], answers 403 at the root like a private bucket, and
   404 to every other path. *)
let with_server f =
  Thread_safe.block_on_async_exn (fun () ->
      let%bind server =
        Cohttp_async.Server.create ~on_handler_error:`Raise
          Tcp.Where_to_listen.of_port_chosen_by_os (fun ~body:_ _ request ->
            let path = Uri.path (Cohttp.Request.uri request) in
            if String.equal path block_path then
              Cohttp_async.Server.respond_string block_body
            else if String.equal path "/" then
              Cohttp_async.Server.respond_string ~status:`Forbidden "denied"
            else
              Cohttp_async.Server.respond_string ~status:`Not_found
                not_found_body )
      in
      let url =
        sprintf "http://127.0.0.1:%d" (Cohttp_async.Server.listening_on server)
      in
      let%bind dir = Unix.mkdtemp "/tmp/missing_blocks_guardian_test" in
      let%bind result = f ~url ~dir in
      let%map () = Cohttp_async.Server.close server in
      result )

let test_download_not_found () =
  with_server (fun ~url ~dir ->
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

(* A private bucket answers 403 at its root and exists; a bucket that
   answers 404 does not; a file bucket is a directory. *)
let test_probe () =
  with_server (fun ~url ~dir ->
      let%bind private_bucket = Download.probe ~url in
      Alcotest.(check bool)
        "403 at the root is a bucket" true
        (Or_error.is_ok private_bucket) ;
      let%bind missing = Download.probe ~url:(url ^ "/no-such-bucket") in
      ( match missing with
      | Ok () ->
          Alcotest.fail "expected an error"
      | Error err ->
          Alcotest.(check bool)
            "says the bucket does not exist" true
            (String.is_substring (Error.to_string_hum err)
               ~substring:"the bucket does not exist" ) ) ;
      let%bind directory = Download.probe ~url:("file://" ^ dir) in
      Alcotest.(check bool) "directory" true (Or_error.is_ok directory) ;
      let%bind no_directory = Download.probe ~url:("file://" ^ dir ^ "/none") in
      Alcotest.(check bool) "no directory" true (Or_error.is_error no_directory) ;
      let%map unreachable = Download.probe ~url:"http://127.0.0.1:1" in
      Alcotest.(check bool) "unreachable" true (Or_error.is_error unreachable) )

let test_download_ok () =
  with_server (fun ~url ~dir ->
      let file = dir ^/ "mainnet-5-3NKabc.json" in
      match%bind Download.fetch ~url:(url ^ block_path) ~file with
      | Error err ->
          Alcotest.fail (Error.to_string_hum err)
      | Ok () ->
          let%map contents = Reader.file_contents file in
          Alcotest.(check string) "saved body" block_body contents )

let test_download_missing_file_url () =
  with_server (fun ~url:_ ~dir ->
      let file = dir ^/ "out.json" in
      match%map
        Download.fetch ~url:("file://" ^ dir ^ "/absent.json") ~file
      with
      | Ok () ->
          Alcotest.fail "expected an error"
      | Error _ ->
          () )

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
    ; ( "download"
      , [ Alcotest.test_case "not found is an error" `Quick
            test_download_not_found
        ; Alcotest.test_case "success saves the body" `Quick test_download_ok
        ; Alcotest.test_case "missing file url is an error" `Quick
            test_download_missing_file_url
        ; Alcotest.test_case "probe of the bucket" `Quick test_probe
        ] )
    ]
