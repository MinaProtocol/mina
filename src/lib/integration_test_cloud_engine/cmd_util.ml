open Core
open Async

let run_cmd dir prog args =
  Process.create_exn ~working_dir:dir ~prog ~args ()
  >>= Process.collect_output_and_wait

let run_cmd_exn dir prog args =
  let open Process.Output in
  let%bind output = run_cmd dir prog args in
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
             (List.map args ~f:(fun arg -> "\"" ^ arg ^ "\"")) )) ;
    print_endline "=== STDOUT ===" ;
    print_endline (indent output.stdout) ;
    print_endline "=== STDERR ===" ;
    print_endline (indent output.stderr) ;
    Writer.(flushed (Lazy.force stdout))
  in
  match output.exit_status with
  | Ok () ->
      return ()
  | Error (`Exit_non_zero status) ->
      let%map () = print_output () in
      failwithf "command exited with status code %d" status ()
  | Error (`Signal signal) ->
      let%map () = print_output () in
      failwithf "command exited prematurely due to signal %d"
        (Signal.to_system_int signal)
        ()
