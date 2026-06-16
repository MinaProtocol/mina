(* Hermetic alcotest smoke tests for rosetta-client.

   These exercise only the subcommands that don't need a running
   Rosetta server: --help for each subgroup, config show / export, and
   the clean error paths of the HTTP and JSON-validation code.

   The regression guard we care most about is that user-visible error
   output never leaks raw OCaml exception syntax (e.g. Unix_error,
   Core.Unix.Unix_error, etc.).  See [assert_no_ocaml_exn_leak]. *)

open Core

(* Path to the binary under test.  dune places the test executable in
   the same directory as its deps, so [../rosetta_client_cli.exe] is reachable from
   wherever dune chooses to [chdir] into.  We resolve it once relative
   to [Sys.get_argv ().(0)] so the tests survive dune sandboxing. *)
let bin =
  let here = Filename.dirname (Array.get (Sys.get_argv ()) 0) in
  Filename.concat here "../rosetta_client_cli.exe"

(* Tempdir helper. *)
let with_tmp_dir f =
  let dir = Core_unix.mkdtemp (Filename.temp_dir_name ^/ "mrc-test-") in
  Exn.protect
    ~f:(fun () -> f dir)
    ~finally:(fun () ->
      let pi = Core_unix.create_process ~prog:"rm" ~args:[ "-rf"; dir ] in
      Core_unix.close pi.stdin ;
      Core_unix.close pi.stdout ;
      Core_unix.close pi.stderr ;
      ignore (Core_unix.waitpid pi.pid : _) )

let read_all_fd fd =
  let ic = Core_unix.in_channel_of_descr fd in
  let s = In_channel.input_all ic in
  In_channel.close ic ; s

(* Spawn the CLI with [args] and an optional env extension, capture
   stdout and stderr, return [(exit_code, stdout, stderr)]. *)
let run_cli ?(env = []) args =
  let pi = Core_unix.create_process_env ~prog:bin ~args ~env:(`Extend env) () in
  (* Close stdin immediately so the child gets EOF if it ever tried to
     read. *)
  Core_unix.close pi.stdin ;
  let out = read_all_fd pi.stdout in
  let err = read_all_fd pi.stderr in
  let status = Core_unix.waitpid pi.pid in
  let code =
    match status with
    | Ok () ->
        0
    | Error (`Exit_non_zero n) ->
        n
    | Error (`Signal s) ->
        128 + Signal.to_system_int s
  in
  (code, out, err)

(* Regression guard: no user-facing output must contain raw OCaml
   exception syntax.  The triggering bug for this whole cleanup was
   connection-refused paths leaking [Unix_error] through to stderr. *)
let assert_no_ocaml_exn_leak label s =
  let needles = [ "Unix_error"; "(Unix."; "Core.Unix" ] in
  List.iter needles ~f:(fun needle ->
      if String.is_substring s ~substring:needle then
        Alcotest.failf "%s: output leaked OCaml exception syntax (%s):\n%s"
          label needle s )

let contains ?(case_insensitive = false) s ~sub =
  if case_insensitive then
    String.is_substring (String.lowercase s) ~substring:(String.lowercase sub)
  else String.is_substring s ~substring:sub

let check_contains ~label s ~sub =
  if not (contains s ~sub) then
    Alcotest.failf "%s: expected to contain %S, got:\n%s" label sub s

(* ---------- Tests ---------- *)

let test_help_root () =
  let code, out, err = run_cli [ "--help" ] in
  Alcotest.(check int) "--help exit" 0 code ;
  check_contains ~label:"--help root lists network" out ~sub:"network" ;
  check_contains ~label:"--help root lists construction" out ~sub:"construction" ;
  assert_no_ocaml_exn_leak "--help root stderr" err

let test_help_network () =
  let code, out, err = run_cli [ "network"; "--help" ] in
  Alcotest.(check int) "network --help exit" 0 code ;
  check_contains ~label:"network --help lists list" out ~sub:"list" ;
  check_contains ~label:"network --help lists status" out ~sub:"status" ;
  check_contains ~label:"network --help lists options" out ~sub:"options" ;
  assert_no_ocaml_exn_leak "network --help stderr" err

let test_help_construction () =
  let code, out, err = run_cli [ "construction"; "--help" ] in
  Alcotest.(check int) "construction --help exit" 0 code ;
  check_contains ~label:"construction --help lists derive" out ~sub:"derive" ;
  check_contains ~label:"construction --help lists submit" out ~sub:"submit" ;
  assert_no_ocaml_exn_leak "construction --help stderr" err

let test_help_config () =
  let code, out, err = run_cli [ "config"; "--help" ] in
  Alcotest.(check int) "config --help exit" 0 code ;
  check_contains ~label:"config --help lists show" out ~sub:"show" ;
  check_contains ~label:"config --help lists export" out ~sub:"export" ;
  assert_no_ocaml_exn_leak "config --help stderr" err

let test_config_show_json () =
  let code, out, err = run_cli [ "config"; "show"; "--file"; "config.json" ] in
  Alcotest.(check int) "config show --file config.json exit" 0 code ;
  let trimmed = String.strip out in
  if String.is_empty trimmed then
    Alcotest.failf "config show: stdout empty, stderr: %s" err ;
  let c = String.get trimmed 0 in
  if not (Char.equal c '{') then
    Alcotest.failf
      "config show: stdout should start with '{' (got %C)\nfull:\n%s" c out ;
  assert_no_ocaml_exn_leak "config show stderr" err

(* The rosetta-cli-config sources are declared as [deps] in the dune
   file, so dune makes them reachable at this relative path under the
   test's sandbox cwd.  Keep this in sync with the [(deps ...)] stanza
   if new files are added. *)
let rosetta_cli_config_src name = "../../rosetta-cli-config" ^/ name

let read_file_bytes path = In_channel.with_file path ~f:In_channel.input_all

let test_config_export_writes_four_files () =
  with_tmp_dir (fun dir ->
      let out_dir = dir ^/ "exp" in
      let code, _out, err =
        run_cli [ "config"; "export"; "--out-dir"; out_dir ]
      in
      Alcotest.(check int) "config export exit" 0 code ;
      assert_no_ocaml_exn_leak "config export stderr" err ;
      let expected =
        [ "config.json"
        ; "mina.ros"
        ; "mina-no-delegation-test.ros"
        ; "mina-with-return-funds.ros"
        ]
      in
      List.iter expected ~f:(fun name ->
          let exported = out_dir ^/ name in
          if not (Sys_unix.file_exists_exn exported) then
            Alcotest.failf "config export: missing %s in %s" name out_dir ;
          let source = rosetta_cli_config_src name in
          let source_bytes = read_file_bytes source in
          let exported_bytes = read_file_bytes exported in
          Alcotest.(check string)
            (name ^ " contents") source_bytes exported_bytes ) )

let test_connection_refused_clean_error () =
  (* Port 1 is privileged and reliably refuses on loopback. *)
  let code, out, err =
    run_cli [ "network"; "status"; "--rosetta-uri"; "http://127.0.0.1:1" ]
  in
  Alcotest.(check int) "network status (dead port) exit" 1 code ;
  assert_no_ocaml_exn_leak "network status stdout" out ;
  assert_no_ocaml_exn_leak "network status stderr" err ;
  let combined = out ^ "\n" ^ err in
  let has_signal =
    contains ~case_insensitive:true combined ~sub:"refused"
    || contains ~case_insensitive:true combined ~sub:"unreachable"
    || contains combined ~sub:"127.0.0.1:1"
  in
  if not has_signal then
    Alcotest.failf
      "network status (dead port): stderr should signal refusal / URI, got:\n\
       stdout=%s\n\
       stderr=%s"
      out err

let test_block_get_missing_args () =
  let code, out, err =
    run_cli [ "block"; "get"; "--rosetta-uri"; "http://127.0.0.1:1" ]
  in
  if code = 0 then
    Alcotest.failf "block get (no --index/--hash): expected non-zero exit" ;
  assert_no_ocaml_exn_leak "block get stdout" out ;
  assert_no_ocaml_exn_leak "block get stderr" err ;
  let combined = out ^ "\n" ^ err in
  if String.is_empty (String.strip combined) then
    Alcotest.failf "block get (no --index/--hash): expected a diagnostic"

let test_construction_derive_invalid_json () =
  let code, out, err =
    run_cli
      [ "construction"
      ; "derive"
      ; "--public-key-json"
      ; "{not valid"
      ; "--rosetta-uri"
      ; "http://127.0.0.1:1"
      ]
  in
  if code = 0 then
    Alcotest.failf "construction derive (bad JSON): expected non-zero exit" ;
  assert_no_ocaml_exn_leak "construction derive stdout" out ;
  assert_no_ocaml_exn_leak "construction derive stderr" err ;
  let combined = out ^ "\n" ^ err in
  if
    not
      ( contains ~case_insensitive:true combined ~sub:"json"
      || contains combined ~sub:"public-key-json" )
  then
    Alcotest.failf
      "construction derive (bad JSON): stderr should mention JSON, got:\n\
       stdout=%s\n\
       stderr=%s"
      out err

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "rosetta-client CLI smoke tests"
    [ ( "help"
      , [ ("root", `Quick, test_help_root)
        ; ("network", `Quick, test_help_network)
        ; ("construction", `Quick, test_help_construction)
        ; ("config", `Quick, test_help_config)
        ] )
    ; ( "config"
      , [ ("show json", `Quick, test_config_show_json)
        ; ( "export writes four files"
          , `Quick
          , test_config_export_writes_four_files )
        ] )
    ; ( "error paths"
      , [ ( "connection refused is clean"
          , `Quick
          , test_connection_refused_clean_error )
        ; ("block get missing args", `Quick, test_block_get_missing_args)
        ; ( "construction derive invalid JSON"
          , `Quick
          , test_construction_derive_invalid_json )
        ] )
    ]
