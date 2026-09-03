(* Helpers shared by the alcotest suites of [rosetta-client] and
   [rosetta-healthcheck].  See [rosetta_cli_test_helpers.mli]. *)

open Core
open Async

let exe_beside_test name =
  let here = Filename.dirname (Array.get (Sys.get_argv ()) 0) in
  Filename.concat here (Filename.concat ".." name)

let run_cli ~bin ?(env = []) args =
  Thread_safe.block_on_async_exn (fun () ->
      let%bind process =
        Process.create_exn ~prog:bin ~args ~env:(`Extend env) ()
      in
      let%map output = Process.collect_output_and_wait process in
      let code =
        match output.exit_status with
        | Ok () ->
            0
        | Error (`Exit_non_zero n) ->
            n
        | Error (`Signal s) ->
            128 + Signal_unix.to_system_int s
      in
      (code, output.stdout, output.stderr) )

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
