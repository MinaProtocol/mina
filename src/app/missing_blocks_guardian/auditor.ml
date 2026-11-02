(* auditor.ml -- run mina-missing-blocks-auditor and read its log *)

open Core
open Async

type missing_parent = { hash : string; height : int }

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
   reports. Its exit code is a bit set of the problems it found, so only its
   log is read. Exits with 1 if it cannot run or its log cannot be read. *)
let check ~logger ~prog ~archive_uri =
  let uri = Uri.to_string archive_uri in
  let log_metadata = [ ("prog", `String prog) ] in
  match%bind
    Subprocess.run ~logger ~secrets:[ uri ] ~prog ~args:[ "--archive-uri"; uri ]
      ()
  with
  | Error err ->
      [%log fatal] "Could not run $prog: $error"
        ~metadata:(("error", `String (Error.to_string_hum err)) :: log_metadata) ;
      exit 1
  | Ok output -> (
      match App_log.parse output.stdout with
      | Error err ->
          [%log fatal] "Could not read the log of $prog: $error"
            ~metadata:
              (("error", `String (Error.to_string_hum err)) :: log_metadata) ;
          exit 1
      | Ok messages ->
          App_log.relay ~logger messages ;
          return (List.find_map messages ~f:missing_parent) )
