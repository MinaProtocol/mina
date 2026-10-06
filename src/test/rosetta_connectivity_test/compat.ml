(* The archive schema scripts against a live archive: upgrade twice (the second
   must be a no-op), then downgrade and upgrade again, twice. After each round
   the archive must keep writing blocks. *)

open Core
open Async
open Mina_automation
module Progress = Rosetta_load.Progress

let run_script (config : Harness.Config.t) script =
  match Archive.Scripts.filepath script with
  | None ->
      Deferred.Or_error.errorf "cannot find %s" (Archive.Scripts.file script)
  | Some file ->
      Psql.run_script_logged
        ~connection:(Harness.Config.connection config)
        ~on_error_stop:true
        ~log_file:(Harness.Config.log config "schema-scripts.log")
        file
      |> Deferred.Or_error.tag ~tag:(Archive.Scripts.file script)

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
