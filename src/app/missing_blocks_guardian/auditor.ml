(* auditor.ml -- run mina-missing-blocks-auditor and read its log *)

open Core
open Async

type missing_parent = { hash : string; height : int } [@@deriving equal]

(* The auditor logs each block whose parent is missing with the parent's
   hash and height in the metadata. *)
let missing_parent (message : Logger.Message.t) =
  match
    ( Map.find message.metadata "parent_hash"
    , Map.find message.metadata "parent_height" )
  with
  | Some (`String hash), Some (`Int height) ->
      Some { hash; height }
  | _ ->
      None

(* Runs the auditor, relays its log and returns the first missing parent it
   reports. Its exit code is a bit set of the problems it found, and a
   database error also exits with 1, so its log tells whether it failed: an
   error in the log, or no log at all, is a failure. Exits with 1 on a
   failure. *)
let check ~logger ~prog ~archive_uri =
  let uri = Uri.to_string archive_uri in
  let failed error =
    [%log fatal] "$prog failed: $error"
      ~metadata:[ ("prog", `String prog); ("error", `String error) ] ;
    exit 1
  in
  match%bind
    Subprocess.run ~logger ~secrets:[ uri ] ~prog ~args:[ "--archive-uri"; uri ]
      ()
  with
  | Error err ->
      failed (sprintf "it could not be run: %s" (Error.to_string_hum err))
  | Ok output -> (
      let messages, other_lines = App_log.parse output.stdout in
      App_log.relay ~logger messages ;
      App_log.warn_other_lines ~logger ~prog other_lines ;
      match (App_log.first_error messages, output.exit_status) with
      | Some message, _ ->
          failed (App_log.describe message)
      | None, _ when List.is_empty messages ->
          failed "it wrote no log message; is it mina-missing-blocks-auditor?"
      | None, Error (`Signal signal) ->
          failed
            (sprintf "it was killed by signal %s%s" (Signal.to_string signal)
               (Subprocess.wrote output) )
      | None, (Ok () | Error (`Exit_non_zero _)) ->
          return (List.find_map messages ~f:missing_parent) )
