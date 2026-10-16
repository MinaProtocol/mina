(**
Module to fill an archive database that the caller has created: with the
empty schema, a local dump, or a network's newest public dump.
*)

open Core
open Async

type source =
  [ `Schema  (** create_schema.sql only *)
  | `Dump of string  (** a local pg_dump .sql file *)
  | `Latest_public_dump of string * int
    (** network prefix and maximum age in days, see [Archive_dumps] *) ]

(* The newest public dump, downloaded and extracted into [workdir]. *)
let fetch_latest_public_dump ~prefix ~max_age_days ~workdir =
  match%bind Archive_dumps.find_latest_date ~prefix ~max_age_days with
  | None ->
      Deferred.Or_error.errorf "no %s archive dump in the last %d days" prefix
        (max_age_days + 1)
  | Some date ->
      Deferred.Or_error.try_with (fun () ->
          let%bind archive =
            Archive_dumps.download_via_public_url ~prefix ~date ~target:workdir
          in
          let%bind _ = Utils.untar ~archive ~output:workdir in
          let%map () = Unix.unlink archive in
          workdir ^/ Archive_dumps.sql_name ~prefix ~date )

(* psql carries on past a failing statement in a dump restore, so a dump that
   is cut short still restores "successfully". A restored dump has blocks; an
   empty [blocks] table is a failed restore. *)
let check_restored ~connection ~log_file =
  match%map Psql.run_command ~connection "SELECT count(*) FROM blocks" with
  | Ok count -> (
      match Option.try_with (fun () -> Int.of_string count) with
      | Some n when n > 0 ->
          Ok ()
      | _ ->
          Or_error.errorf "the restored dump has %s blocks, see %s" count
            log_file )
  | Error e ->
      Error (Error.tag e ~tag:(sprintf "the restored dump, see %s" log_file))

(** [prepare ~postgres_uri ~source ~workdir ~log_file] loads [source] into the
    database [postgres_uri] names, with psql output in [log_file], then waits
    until the archive schema answers. A restored dump must have blocks. A
    public dump is several GB once extracted, so it is deleted after the
    restore.

    A public dump creates and connects to a database named [archive]; restore
    one only into a database of that name. *)
let prepare ~postgres_uri ~(source : source) ~workdir ~log_file =
  let open Deferred.Or_error.Let_syntax in
  let connection = Psql.Conn_str (Uri.to_string postgres_uri) in
  let restore file = Psql.run_script_logged ~connection ~log_file file in
  let%bind () =
    match source with
    | `Schema ->
        let%bind schema = Deferred.ok (Psql.create_db_script ()) in
        restore schema
    | `Dump file ->
        let%bind () = restore file in
        check_restored ~connection ~log_file
    | `Latest_public_dump (prefix, max_age_days) ->
        let%bind file =
          fetch_latest_public_dump ~prefix ~max_age_days ~workdir
        in
        let%bind () = restore file in
        let%bind () = Deferred.ok (Unix.unlink file) in
        check_restored ~connection ~log_file
  in
  Archive_healthcheck.wait_db_ready
    ~postgres_uri:(Uri.to_string postgres_uri)
    ()
