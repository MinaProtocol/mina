(* The archive schema scripts against a live archive: upgrade twice (the second
   must be a no-op), then downgrade and upgrade again, twice. After each round
   the archive must keep writing blocks. *)

open Core
open Async
open Mina_automation
module Progress = Rosetta_load.Progress

(* upgrade.sql and downgrade.sql set lock_timeout = '10s' and stop rather than
   wait behind the archive's block inserts: their CREATE INDEX and DROP INDEX on
   user_commands need locks that conflict with those writes. On a live archive
   that stop is intended and the scripts are idempotent, so a lock timeout is
   run again instead of failing the test. *)
let lock_timeout_attempts = 6

let lock_timeout_wait = Time.Span.of_sec 10.

let file_size file =
  match%map Monitor.try_with (fun () -> Unix.stat file) with
  | Ok stat ->
      Int64.to_int_exn stat.size
  | Error _ ->
      0

(* the part of [file] written after byte [from] *)
let read_from file ~from =
  let%map contents = Reader.file_contents file in
  String.drop_prefix contents (min from (String.length contents))

let run_script (config : Harness.Config.t) script =
  match Archive.Scripts.filepath script with
  | None ->
      Deferred.Or_error.errorf "cannot find %s" (Archive.Scripts.file script)
  | Some file ->
      let name = Archive.Scripts.file script in
      let log_file = Harness.Config.log config "schema-scripts.log" in
      let rec attempt n =
        let%bind from = file_size log_file in
        match%bind
          Psql.run_script_logged
            ~connection:(Harness.Config.connection config)
            ~on_error_stop:true ~log_file file
        with
        | Ok () ->
            Deferred.Or_error.return ()
        | Error _ as error ->
            let%bind output = read_from log_file ~from in
            if
              n < lock_timeout_attempts
              && String.is_substring output
                   ~substring:"canceling statement due to lock timeout"
            then (
              Progress.printf "compat: %s hit a lock timeout (attempt %d/%d)"
                name n lock_timeout_attempts ;
              let%bind () = after lock_timeout_wait in
              attempt (n + 1) )
            else return error
      in
      attempt 1 |> Deferred.Or_error.tag ~tag:name

let wait_for_new_blocks ~db ~since ~timeout ~label =
  let deadline = Time.add (Time.now ()) timeout in
  let rec loop () =
    let%bind.Deferred.Or_error count = Rosetta_load.Sql.block_count db in
    if count > since then (
      Progress.printf "compat %s: %d blocks (was %d)" label count since ;
      Deferred.Or_error.return () )
    else if Time.( > ) (Time.now ()) deadline then
      Deferred.Or_error.errorf "compat %s: no new block in %s (still %d)" label
        (Time.Span.to_string_hum timeout)
        since
    else
      let%bind () = after (Time.Span.of_sec 10.) in
      loop ()
  in
  loop ()

let run (config : Harness.Config.t) ~db ~new_block_timeout =
  let open Deferred.Or_error.Let_syntax in
  let round label scripts =
    let%bind () = Deferred.Or_error.List.iter scripts ~f:(run_script config) in
    (* counted after the scripts, so a block written while they ran does not
       stand in for the archive still working after them *)
    let%bind since = Rosetta_load.Sql.block_count db in
    wait_for_new_blocks ~db ~since ~timeout:new_block_timeout ~label
  in
  let%bind () = round "double upgrade" [ `Upgrade; `Upgrade ] in
  let%bind () = round "downgrade and upgrade" [ `Rollback; `Upgrade ] in
  round "second downgrade and upgrade" [ `Rollback; `Upgrade ]
