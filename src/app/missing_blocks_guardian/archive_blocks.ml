(* archive_blocks.ml -- run mina-archive-blocks and read its log *)

open Core
open Async

(* Writes [file] to the archive and relays the log of the program. Its exit
   code is 0 even when the block was not added, so an error in its log is a
   failure. A failure is an [Error] with the reason. *)
let add ~logger ~prog ~format ~archive_uri file =
  let uri = Uri.to_string archive_uri in
  let failed error =
    Error
      (sprintf "%s could not add %s: %s. The database remains unhealthy." prog
         file error )
  in
  match%map
    Subprocess.run ~logger ~secrets:[ uri ] ~prog
      ~args:
        [ "--" ^ Config.Block_format.to_string format
        ; "--archive-uri"
        ; uri
        ; file
        ]
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
      | None, Error (`Exit_non_zero code) ->
          failed (sprintf "it exited with %d%s" code (Subprocess.wrote output))
      | None, Error (`Signal signal) ->
          failed
            (sprintf "it was killed by signal %s%s" (Signal.to_string signal)
               (Subprocess.wrote output) )
      | None, Ok () ->
          Ok () )
