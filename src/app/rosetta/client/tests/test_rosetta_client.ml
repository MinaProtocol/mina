(* Hermetic alcotest smoke tests for rosetta-client.

   These exercise only the subcommands that don't need a running
   Rosetta server: --help for each subgroup and the clean error paths of
   the HTTP code.

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
        128 + Signal_unix.to_system_int s
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
  check_contains ~label:"--help root lists search" out ~sub:"search" ;
  assert_no_ocaml_exn_leak "--help root stderr" err

let test_help_network () =
  let code, out, err = run_cli [ "network"; "--help" ] in
  Alcotest.(check int) "network --help exit" 0 code ;
  check_contains ~label:"network --help lists list" out ~sub:"list" ;
  check_contains ~label:"network --help lists status" out ~sub:"status" ;
  check_contains ~label:"network --help lists options" out ~sub:"options" ;
  assert_no_ocaml_exn_leak "network --help stderr" err

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

(* ---------- Runner ---------- *)

let () =
  Alcotest.run "rosetta-client CLI smoke tests"
    [ ( "help"
      , [ ("root", `Quick, test_help_root)
        ; ("network", `Quick, test_help_network)
        ] )
    ; ( "error paths"
      , [ ( "connection refused is clean"
          , `Quick
          , test_connection_refused_clean_error )
        ; ("block get missing args", `Quick, test_block_get_missing_args)
        ] )
    ]
