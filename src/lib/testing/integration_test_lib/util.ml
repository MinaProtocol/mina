open Core
open Async
include Mina_automation_process.Cmd

let run_cmd_or_hard_error ?exit_code ?env dir prog args =
  let%bind output = run_cmd dir prog args ?env () in
  Deferred.bind
    ~f:(Malleable_error.or_hard_error ?exit_code)
    (check_cmd_output ~prog ~args output)

let rec prompt_continue prompt_string =
  print_string prompt_string ;
  let%bind () = Writer.flushed (Lazy.force Writer.stdout) in
  let c = Option.value_exn In_channel.(input_char stdin) in
  print_newline () ;
  if Char.equal c 'y' || Char.equal c 'Y' then Deferred.unit
  else prompt_continue prompt_string
