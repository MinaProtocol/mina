(* app_log.ml -- the log that a Mina program writes to stdout: one JSON
   message on each line *)

open Core

(* The messages in [output], and the lines that are not messages. *)
let parse output =
  String.split_lines output
  |> List.filter ~f:(fun line -> not (String.is_empty (String.strip line)))
  |> List.partition_map ~f:(fun line ->
         match
           Or_error.try_with (fun () ->
               Yojson.Safe.from_string line |> Logger.Message.of_yojson )
         with
         | Ok (Ok message) ->
             First message
         | Ok (Error _) | Error _ ->
             Second line )

(* Sends each message to the consumers of [logger], as if logged here. *)
let relay ~logger messages = List.iter messages ~f:(Logger.raw logger)

let warn_other_lines ~logger ~prog = function
  | [] ->
      ()
  | lines ->
      [%log warn] "$prog wrote lines that are not log messages: $lines"
        ~metadata:
          [ ("prog", `String prog)
          ; ("lines", `List (List.map lines ~f:(fun line -> `String line)))
          ]

(* The first message at level Error or above. *)
let first_error messages =
  List.find messages ~f:(fun (message : Logger.Message.t) ->
      Logger.Level.compare message.level Logger.Level.Error >= 0 )

(* The text of a message and of its "error" metadata, for a log line about
   it. *)
let describe (message : Logger.Message.t) =
  match Map.find message.metadata "error" with
  | Some (`String error) ->
      message.message ^ ": " ^ error
  | Some json ->
      message.message ^ ": " ^ Yojson.Safe.to_string json
  | None ->
      message.message
