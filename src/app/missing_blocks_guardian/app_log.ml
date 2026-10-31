(* app_log.ml -- the log that a Mina program writes to stdout: one JSON
   message on each line *)

open Core

let parse output =
  Or_error.try_with (fun () ->
      String.split_lines output
      |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))
      |> List.map ~f:(fun line ->
             Yojson.Safe.from_string line
             |> Logger.Message.of_yojson |> Result.ok_or_failwith ) )

(* Sends each message to the consumers of [logger], as if logged here. *)
let relay ~logger messages = List.iter messages ~f:(Logger.raw logger)
