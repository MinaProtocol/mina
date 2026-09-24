(* The archive schema scripts against a live archive: upgrade twice (the second
   must be a no-op), then downgrade and upgrade again, twice. After each round
   the archive must keep writing blocks. *)

open Core
open Async

let run_script (config : Harness.Config.t) ~name =
  let script = config.repo_root ^/ "src/app/archive" ^/ name in
  Proc.run_logged
    ~log_file:(Harness.Config.log config "schema-scripts.log")
    "psql"
    [ Uri.to_string config.postgres_uri; "-v"; "ON_ERROR_STOP=1"; "-f"; script ]
  |> Deferred.Or_error.tag ~tag:name

let wait_for_new_blocks ~db ~since ~timeout ~label =
  let deadline = Time.add (Time.now ()) timeout in
  let rec loop () =
    let%bind.Deferred.Or_error count = Db.block_count db in
    if count > since then (
      Proc.log "compat %s: %d blocks (was %d)" label count since ;
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
    let%bind () =
      Deferred.Or_error.List.iter scripts ~f:(fun name ->
          run_script config ~name )
    in
    (* counted after the scripts, so a block written while they ran does not
       stand in for the archive still working after them *)
    let%bind since = Db.block_count db in
    wait_for_new_blocks ~db ~since ~timeout:new_block_timeout ~label
  in
  let%bind () = round "double upgrade" [ "upgrade.sql"; "upgrade.sql" ] in
  let%bind () =
    round "downgrade and upgrade" [ "downgrade.sql"; "upgrade.sql" ]
  in
  round "second downgrade and upgrade" [ "downgrade.sql"; "upgrade.sql" ]
