open Core

let read_hidden_line prompt : Bytes.t Async.Deferred.t =
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
        {(Option.value_exn old_termios) with c_echo= false; c_echonl= true}
        stdin
  in
  Writer.write (Lazy.force Writer.stdout) prompt ;
  let%map pwd = Reader.read_line (Lazy.force Reader.stdin) in
  if isatty then
    Terminal_io.tcsetattr ~mode:Terminal_io.TCSANOW
      (Option.value_exn old_termios)
      stdin ;
  match pwd with
  | `Ok pwd -> Bytes.of_string pwd
  | `Eof -> failwith "got EOF while reading password"

let lift (t : 'a Async.Deferred.t) : 'a Async.Deferred.Or_error.t =
  Async.Deferred.map t ~f:(fun x -> Ok x)

let hidden_line_or_env prompt ~env : Bytes.t Async.Deferred.Or_error.t =
  let open Async.Deferred.Or_error.Let_syntax in
  match Sys.getenv env with
  | Some p -> return (Bytes.of_string p)
  | _ -> lift (read_hidden_line prompt)

let read prompt = hidden_line_or_env prompt ~env:"CODA_PRIVKEY_PASS"
