open Core
open Async
open Coda_worker
open Coda_main

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) :
  Integration_test_intf.S =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  let name = "coda-block-production-test"

  let main () =
    Coda_processes.init () ;
    let discovery_port = 3001 in
    let external_port = 3000 in
    let peers = [] in
    let%bind program_dir = Unix.getcwd () in
    let log = Logger.create () in
    let log = Logger.child log name in
    Coda_process.spawn_local_exn ~peers ~external_port ~discovery_port
      ~program_dir ~f:(fun worker ->
        let%bind strongest_ledgers =
          Coda_process.strongest_ledgers_exn worker
        in
        let rec go i blocks =
          if i = 10 then return blocks
          else
            let%bind _ = Linear_pipe.read_exn strongest_ledgers in
            go (i + 1) (((), Time.now ()) :: blocks)
        in
        let%bind blocks = go 0 [] in
        let first_block = List.hd_exn blocks in
        let last_block = List.last_exn blocks in
        let first_block_time = snd first_block in
        let last_block_time = snd last_block in
        let time_diff = Time.diff first_block_time last_block_time in
        let time_diff_secs = Time.Span.to_sec time_diff in
        let time_per_block =
          time_diff_secs /. Float.of_int (List.length blocks - 1)
        in
        let expected_time_per_block = 1.00 in
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
end
