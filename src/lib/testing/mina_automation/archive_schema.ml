(** Archive database states for hard fork tests, reached the way production
    reaches them: the schema scripts an operator runs, and the archive's own
    record of a fork. *)

open Core
open Async

let run_script ~postgres_uri script =
  let path =
    Archive.Scripts.filepath script
    |> Option.value_exn
         ~message:(sprintf "Failed to find %s" (Archive.Scripts.file script))
  in
  Psql.run_script ~connection:(Psql.Conn_str postgres_uri) path >>| ignore

let upgrade ~postgres_uri = run_script ~postgres_uri `Upgrade

let downgrade ~postgres_uri = run_script ~postgres_uri `Rollback

let with_connection ~postgres_uri f =
  match%bind Mina_caqti.connect (Uri.of_string postgres_uri) with
  | Error e ->
      failwith (Caqti_error.show e)
  | Ok (module Conn : Mina_caqti.CONNECTION) ->
      let%bind result = f (module Conn : Mina_caqti.CONNECTION) in
      let%map () = Conn.disconnect () in
      Result.map_error result ~f:Caqti_error.show |> Result.ok_or_failwith

(** Record the fork named by [config_json], as the archive does when a daemon
    announces it. *)
let record_fork ~postgres_uri ~config_json =
  let state =
    Archive_lib.Processor.hardfork_state_of_config ~config_json
    |> Result.ok_or_failwith
  in
  match%map
    with_connection ~postgres_uri (fun conn ->
        Archive_lib.Processor.Hardfork_state.record conn
          ~logger:(Logger.null ()) state )
  with
  | Archive_lib.Processor.Hardfork_state.Recorded ->
      ()
  | Already_recorded | Disagrees _ ->
      failwith "a fork was already recorded"

(** Set the status of the latest migration. No script leaves a migration half
    way, so this stands in for one that was interrupted. *)
let set_latest_migration_status ~postgres_uri status =
  with_connection ~postgres_uri (fun (module Conn) ->
      Conn.exec
        (Mina_caqti.exec_req Archive_lib.Processor.Migration_history.Status.typ
           {sql| UPDATE migration_history
                 SET status = ?
                 WHERE commit_start_at =
                   (SELECT max(commit_start_at) FROM migration_history)
           |sql} )
        status )

(** The fork the archive has on record, if any. *)
let recorded_fork ~postgres_uri =
  with_connection ~postgres_uri Archive_lib.Processor.Hardfork_state.load_opt

(** The latest migration the schema went through, if any. *)
let latest_migration ~postgres_uri =
  with_connection ~postgres_uri
    Archive_lib.Processor.Migration_history.latest_opt
