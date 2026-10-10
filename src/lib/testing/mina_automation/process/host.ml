(** Host lookups and process control shared by every app driver. *)

open Async
open Core

let paths =
  Option.value_map ~f:(String.split ~on:':') ~default:[] (Sys.getenv "PATH")

let possible_locations ~file possible_locations =
  let exists_at_path folder file =
    match Sys.file_exists (folder ^/ file) with
    | `Yes ->
        Some (folder ^/ file)
    | _ ->
        None
  in

  possible_locations @ paths
  |> List.find_map ~f:(fun folder -> exists_at_path folder file)

let force_kill process =
  Process.send_signal process Core.Signal.kill ;
  match%map Process.wait process with
  | Ok () ->
      Ok (`Exited 0)
  | Error (`Exit_non_zero exit_code) ->
      Ok (`Exited exit_code)
  | Error (`Signal signal) when Signal.(equal signal kill) ->
      Ok `Sig_killed
  | Error (`Signal signal) ->
      Or_error.errorf "Process exited with signal %s" (Signal.to_string signal)
