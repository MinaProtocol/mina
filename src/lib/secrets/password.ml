open Core

let read_hidden_line ~error_help_message prompt : Bytes.t Async.Deferred.t =
  let open Unix in
  let open Async_unix in
  let open Async.Deferred.Let_syntax in
  let isatty = isatty stdin in
  let old_termios =
    if isatty then Some (Terminal_io.tcgetattr stdin) else None
  in
  let () =
    if isatty then
      Terminal_io.tcsetattr ~mode:Terminal_io.TCSANOW
        { (Option.value_exn old_termios) with c_echo = false; c_echonl = true }
        stdin
  in
  Writer.write (Lazy.force Writer.stdout) prompt ;
  let%map pwd =
    if isatty then Reader.read_line (Lazy.force Reader.stdin)
    else
      (* Don't attempt to read the password if stdin isn't a tty, to avoid a
         hang waiting for input.
      *)
      return `Eof
  in
  if isatty then
    Terminal_io.tcsetattr ~mode:Terminal_io.TCSANOW
      (Option.value_exn old_termios)
      stdin ;
  match pwd with
  | `Ok pwd ->
      Bytes.of_string pwd
  | `Eof ->
      Mina_user_error.raisef {|No password was provided.

%s|}
        error_help_message

let hidden_line_or_env ?error_help_message prompt ~env :
    Bytes.t Async.Deferred.t =
  let open Async.Deferred.Let_syntax in
  match Sys.getenv env with
  | Some p ->
      return (Bytes.of_string p)
  | _ ->
      let error_help_message =
        match error_help_message with
        | None ->
            sprintf "Set the %s environment variable to the password" env
        | Some s ->
            s
      in
      read_hidden_line ~error_help_message prompt
