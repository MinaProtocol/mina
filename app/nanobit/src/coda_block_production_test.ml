open Core
open Async
open Coda_worker
open Coda_processes

let name = "coda-block-production-test"

let main () =
  Coda_processes.init () ;
  let gossip_port = 8000 in
  let port = 3000 in
  let peers = [] in
  let%bind program_dir = Unix.getcwd () in
  let log = Logger.create () in
  let log = Logger.child log name in
  Coda_process.spawn_local_exn ~peers ~port ~gossip_port ~program_dir ~f:
    (fun worker ->
      let%bind strongest_ledgers = Coda_process.strongest_ledgers_exn worker in
      let count = ref 0 in
      let blocks = ref [] in
      let%bind () =
        Deferred.create (fun got_10_blocks ->
            don't_wait_for
              (Linear_pipe.iter strongest_ledgers ~f:(fun () ->
                   Logger.debug log "got ledger\n" ;
                   incr count ;
                   blocks := ((), Time.now ()) :: !blocks ;
                   if !count > 10 then Ivar.fill_if_empty got_10_blocks () ;
                   Deferred.unit )) )
      in
      let blocks = !blocks in
      let first_block = List.hd_exn blocks in
      let last_block = List.last_exn blocks in
      let first_block_time = snd first_block in
      let last_block_time = snd last_block in
      let time_diff = Time.diff first_block_time last_block_time in
      let time_diff_secs = Time.Span.to_sec time_diff in
      let time_per_block =
        time_diff_secs /. Float.of_int (List.length blocks - 1)
      in
      let expected_time_per_block = 0.10 in
      let percent_diff =
        Float.max
          (expected_time_per_block /. time_per_block)
          (time_per_block /. expected_time_per_block)
      in
      let max_percent_diff = 0.10 in
      Logger.info log "percent diff %f\n" percent_diff ;
      assert (Float.(percent_diff < 1. + max_percent_diff)) ;
      let%bind _ = Coda_process.disconnect worker in
      Deferred.unit )

let command =
  Command.async_spec ~summary:"Simple use of Async Rpc_parallel V2"
    Command.Spec.(empty)
    main
