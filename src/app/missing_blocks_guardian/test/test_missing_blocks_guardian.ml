(* Tests of the guardian's settings, of the block download with
   [Mock_bucket] and of the recovery with a fake audit. *)

open Core
open Async
module Config = Missing_blocks_guardian_lib.Config
module Download = Missing_blocks_guardian_lib.Download
module Archive_blocks = Missing_blocks_guardian_lib.Archive_blocks
module Audit = Missing_blocks_auditor_lib.Audit
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
       ~network:(Some "mainnet") ~format:None )

let test_blocks_url () =
  let blocks ~url =
    Config.blocks ~env:no_env ~url:(Some url) ~network:(Some "mainnet")
      ~format:None
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
       ~url:None ~network:(Some "a/b") ~format:None )

let test_both_collects_problems () =
  expect_problems
    ~mentioning:[ "missing --archive-uri"; "missing --precomputed-blocks-url" ]
    (Config.both
       (Config.archive_uri ~env:no_env None)
       (Config.blocks ~env:no_env ~url:None ~network:(Some "mainnet")
          ~format:None ) )

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
    (Uri.to_string archive) ;
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

let blocks ~dir : Config.blocks =
  { url = "file://" ^ dir; network = "mainnet"; format = Config.Default.format }

let healthy : Audit.report =
  { missing_blocks = []
  ; pending_blocks_below_canonical = false
  ; chain_length_differs = false
  ; chain_status_invalid = false
  }

let missing ~parent_hash ~parent_height : Audit.missing_block =
  { parent_hash; parent_height }

(* The auditor exits with a bit for each problem. Scripts read these codes. *)
let test_audit_exit_code () =
  let check name report expected =
    Alcotest.(check int) name expected (Audit.exit_code report)
  in
  check "healthy" healthy 0 ;
  check "missing blocks"
    { healthy with
      missing_blocks = [ missing ~parent_hash:"3NKfour" ~parent_height:4 ]
    }
    1 ;
  check "pending blocks"
    { healthy with pending_blocks_below_canonical = true }
    2 ;
  check "chain length" { healthy with chain_length_differs = true } 4 ;
  check "chain status" { healthy with chain_status_invalid = true } 8 ;
  check "all"
    { missing_blocks = [ missing ~parent_hash:"3NKfour" ~parent_height:4 ]
    ; pending_blocks_below_canonical = true
    ; chain_length_differs = true
    ; chain_status_invalid = true
    }
    15

(* The guardian repairs only the first missing block. *)
let test_first_missing_parent () =
  Alcotest.(check bool)
    "healthy" true
    (Option.is_none (Auditor.first_missing_parent healthy)) ;
  Alcotest.(check bool)
    "other problems are not for the guardian" true
    (Option.is_none
       (Auditor.first_missing_parent
          { healthy with chain_length_differs = true } ) ) ;
  match
    Auditor.first_missing_parent
      { healthy with
        missing_blocks =
          [ missing ~parent_hash:"3NKfour" ~parent_height:4
          ; missing ~parent_hash:"3NKnine" ~parent_height:9
          ]
      }
  with
  | None ->
      Alcotest.fail "expected a missing parent"
  | Some parent ->
      Alcotest.(check string) "hash" "3NKfour" parent.hash ;
      Alcotest.(check int) "height" 4 parent.height

let with_dir f =
  Thread_safe.block_on_async_exn (fun () ->
      let%bind dir = Unix.mkdtemp "/tmp/missing_blocks_guardian_test" in
      f ~dir )

let block_name = "mainnet-5-3NKfive.json"

let block_at_five : Auditor.missing_parent = { hash = "3NKfive"; height = 5 }

(* Runs [populate] on a block file with [contents] in the working directory.
   The file must be removed in every case. *)
let populate ~add_block ~contents =
  let%bind () = Writer.save block_name ~contents in
  let%bind result =
    Recovery.populate ~logger:(Logger.null ()) ~add_block block_name
  in
  let%map exists = Sys.file_exists_exn block_name in
  Alcotest.(check bool) "file removed" false exists ;
  result

let test_populate_ok () =
  Thread_safe.block_on_async_exn (fun () ->
      let added = ref [] in
      let add_block file =
        added := file :: !added ;
        return (Ok ())
      in
      let%map result = populate ~add_block ~contents:Mock_bucket.block_body in
      check_ok "added" result ;
      Alcotest.(check (list string)) "the file" [ block_name ] !added )

let test_populate_failure () =
  Thread_safe.block_on_async_exn (fun () ->
      let add_block _file = return (Error "not added") in
      let%map result = populate ~add_block ~contents:Mock_bucket.block_body in
      expect_error_with ~substring:"not added" result )

(* The real import, on files that fail before the first query. *)
let add_block ~format =
  let pool =
    Result.ok (Mina_caqti.connect_pool archive_uri) |> Option.value_exn
  in
  Archive_blocks.add_block ~logger:(Logger.null ()) ~pool ~format

let test_import_not_json () =
  Thread_safe.block_on_async_exn (fun () ->
      let%map result =
        populate
          ~add_block:(add_block ~format:Config.Block_format.Precomputed)
          ~contents:"not json"
      in
      expect_error_with ~substring:"Could not parse JSON from file" result ;
      expect_error_with ~substring:"The database remains unhealthy" result )

(* The two formats give different errors for the same file. *)
let test_import_format () =
  Thread_safe.block_on_async_exn (fun () ->
      let contents = {|{"a":1}|} in
      let%bind result =
        populate
          ~add_block:(add_block ~format:Config.Block_format.Precomputed)
          ~contents
      in
      expect_error_with ~substring:"missing version tag" result ;
      let%map result =
        populate
          ~add_block:(add_block ~format:Config.Block_format.Extensional)
          ~contents
      in
      expect_error_with ~substring:"Expected versioned JSON" result )

let save_block ~dir ~height ~hash =
  Writer.save
    (dir ^/ sprintf "mainnet-%d-%s.json" height hash)
    ~contents:Mock_bucket.block_body

(* An [add_block] that records its files, and the list of them, oldest
   first. *)
let recording_add_block () =
  let added = ref [] in
  ( (fun file ->
      added := file :: !added ;
      return (Ok ()) )
  , fun () -> List.rev !added )

(* A fake audit that gives the entries of [results], one at each call. *)
let check_in_turn results =
  let results = ref results in
  fun () ->
    match !results with
    | [] ->
        Alcotest.fail "one audit too many"
    | result :: rest ->
        results := rest ;
        return result

let restore ~dir ~check ~add_block =
  Recovery.restore ~logger:(Logger.null ()) ~add_block ~check (blocks ~dir)
    block_at_five

let lacking ~height ~hash : Auditor.missing_parent = { hash; height }

let test_restore_follows_parents () =
  with_dir (fun ~dir ->
      let%bind () = save_block ~dir ~height:5 ~hash:"3NKfive" in
      let%bind () = save_block ~dir ~height:4 ~hash:"3NKfour" in
      let check =
        check_in_turn [ Ok (Some (lacking ~height:4 ~hash:"3NKfour")); Ok None ]
      in
      let add_block, added = recording_add_block () in
      let%map result = restore ~dir ~check ~add_block in
      check_ok "restored" result ;
      Alcotest.(check (list string))
        "imports in order"
        [ block_name; "mainnet-4-3NKfour.json" ]
        (added ()) )

let test_restore_no_progress () =
  with_dir (fun ~dir ->
      let%bind () = save_block ~dir ~height:5 ~hash:"3NKfive" in
      let check =
        check_in_turn [ Ok (Some (lacking ~height:5 ~hash:"3NKfive")) ]
      in
      let add_block, added = recording_add_block () in
      let%map result = restore ~dir ~check ~add_block in
      expect_error_with ~substring:"still lacks block 3NKfive at height 5"
        result ;
      Alcotest.(check (list string)) "one import" [ block_name ] (added ()) )

let test_restore_block_not_in_bucket () =
  with_dir (fun ~dir ->
      let add_block, added = recording_add_block () in
      let%map result = restore ~dir ~check:(check_in_turn []) ~add_block in
      expect_error_with ~substring:"Could not download the block at height 5"
        result ;
      Alcotest.(check (list string)) "no import" [] (added ()) )

let test_restore_audit_fails () =
  with_dir (fun ~dir ->
      let%bind () = save_block ~dir ~height:5 ~hash:"3NKfive" in
      let check = check_in_turn [ Error "The audit failed: no database" ] in
      let add_block, _added = recording_add_block () in
      let%map result = restore ~dir ~check ~add_block in
      expect_error_with ~substring:"no database" result )

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
    ; ("cli", [ Alcotest.test_case "flags reach config" `Quick test_cli_flags ])
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
      , [ Alcotest.test_case "exit code of the audit" `Quick
            test_audit_exit_code
        ; Alcotest.test_case "first missing parent" `Quick
            test_first_missing_parent
        ] )
    ; ( "populate"
      , [ Alcotest.test_case "success" `Quick test_populate_ok
        ; Alcotest.test_case "failure" `Quick test_populate_failure
        ; Alcotest.test_case "real import of a file that is not JSON" `Quick
            test_import_not_json
        ; Alcotest.test_case "real import uses the format" `Quick
            test_import_format
        ] )
    ; ( "restore"
      , [ Alcotest.test_case "follows the missing parents" `Quick
            test_restore_follows_parents
        ; Alcotest.test_case "stops when nothing changes" `Quick
            test_restore_no_progress
        ; Alcotest.test_case "stops when the block is not in the bucket" `Quick
            test_restore_block_not_in_bucket
        ; Alcotest.test_case "stops when the audit fails" `Quick
            test_restore_audit_fails
        ] )
    ]
