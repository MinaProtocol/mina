(* Tests of the guardian's settings, of the reading of a child's log and of
   the block download. *)

open Core
open Async
module Config = Missing_blocks_guardian_lib.Config
module App_log = Missing_blocks_guardian_lib.App_log
module Download = Missing_blocks_guardian_lib.Download

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

let block_path = "/mainnet-5-3NKabc.json"

let block_body = {|{"block":"content"}|}

let not_found_body =
  {|<?xml version='1.0' encoding='UTF-8'?><Error><Code>NoSuchKey</Code></Error>|}

(* Serves [block_path] and answers 404 to every other path. *)
let with_server f =
  Thread_safe.block_on_async_exn (fun () ->
      let%bind server =
        Cohttp_async.Server.create ~on_handler_error:`Raise
          Tcp.Where_to_listen.of_port_chosen_by_os (fun ~body:_ _ request ->
            if String.equal (Uri.path (Cohttp.Request.uri request)) block_path
            then Cohttp_async.Server.respond_string block_body
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
        ; Alcotest.test_case "blocks problems reported together" `Quick
            test_blocks_problems_reported_together
        ; Alcotest.test_case "both collects problems" `Quick
            test_both_collects_problems
        ] )
    ; ("app_log", [ Alcotest.test_case "parse and errors" `Quick test_app_log ])
    ; ( "download"
      , [ Alcotest.test_case "not found is an error" `Quick
            test_download_not_found
        ; Alcotest.test_case "success saves the body" `Quick test_download_ok
        ; Alcotest.test_case "missing file url is an error" `Quick
            test_download_missing_file_url
        ] )
    ]
