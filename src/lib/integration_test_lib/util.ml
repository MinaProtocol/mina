open Core
open Async
module Timeout = Timeout_lib.Core_time

let run_cmd dir prog args =
  [%log' spam (Logger.create ())]
    "Running command (from %s): $command" dir
    ~metadata:[ ("command", `String (String.concat (prog :: args) ~sep:" ")) ] ;
  Process.create_exn ~working_dir:dir ~prog ~args ()
  >>= Process.collect_output_and_wait

let check_cmd_output ~prog ~args output =
  let open Process.Output in
  let print_output () =
    let indent str =
      String.split str ~on:'\n'
      |> List.map ~f:(fun s -> "    " ^ s)
      |> String.concat ~sep:"\n"
    in
    print_endline "=== COMMAND ===" ;
    print_endline
      (indent
         ( prog ^ " "
         ^ String.concat ~sep:" "
             (List.map args ~f:(fun arg -> "\"" ^ arg ^ "\"")) ) ) ;
    print_endline "=== STDOUT ===" ;
    print_endline (indent output.stdout) ;
    print_endline "=== STDERR ===" ;
    print_endline (indent output.stderr) ;
    Writer.(flushed (Lazy.force stdout))
  in
  match output.exit_status with
  | Ok () ->
      return (Ok output.stdout)
  | Error (`Exit_non_zero status) ->
      let%map () = print_output () in
      Or_error.errorf "command exited with status code %d" status
  | Error (`Signal signal) ->
      let%map () = print_output () in
      Or_error.errorf "command exited prematurely due to signal %d"
        (Signal.to_system_int signal)

let run_cmd_or_error_timeout ~timeout_seconds dir prog args =
  [%log' spam (Logger.create ())]
    "Running command (from %s): $command" dir
    ~metadata:[ ("command", `String (String.concat (prog :: args) ~sep:" ")) ] ;
  let open Deferred.Let_syntax in
  let%bind process = Process.create_exn ~working_dir:dir ~prog ~args () in
  let%bind res =
    match%map
      Timeout.await ()
        ~timeout_duration:(Time.Span.create ~sec:timeout_seconds ())
        (Process.collect_output_and_wait process)
    with
    | `Ok output ->
        check_cmd_output ~prog ~args output
    | `Timeout ->
        Deferred.return (Or_error.error_string "timed out running command")
  in
  res

let run_cmd_or_error dir prog args =
  let%bind output = run_cmd dir prog args in
  check_cmd_output ~prog ~args output

let run_cmd_exn dir prog args =
  match%map run_cmd_or_error dir prog args with
  | Ok output ->
      output
  | Error error ->
      Error.raise error

let run_cmd_or_hard_error ?exit_code dir prog args =
  let%bind output = run_cmd dir prog args in
  Deferred.bind
    ~f:(Malleable_error.or_hard_error ?exit_code)
    (check_cmd_output ~prog ~args output)

let run_cmd_exn_timeout ~timeout_seconds dir prog args =
  match%map run_cmd_or_error_timeout ~timeout_seconds dir prog args with
  | Ok output ->
      output
  | Error error ->
      Error.raise error

let rec prompt_continue prompt_string =
  print_string prompt_string ;
  let%bind () = Writer.flushed (Lazy.force Writer.stdout) in
  let c = Option.value_exn In_channel.(input_char stdin) in
  print_newline () ;
  if Char.equal c 'y' || Char.equal c 'Y' then Deferred.unit
  else prompt_continue prompt_string

let write_to_file file_name content =
  let file = Out_channel.create file_name in
  Out_channel.output_string file content ;
  Malleable_error.ok_unit
