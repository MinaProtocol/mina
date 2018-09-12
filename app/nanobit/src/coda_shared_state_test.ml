open Core
open Async
open Coda_worker
open Coda_main
open Nanobit_base

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) :
  Integration_test_intf.S =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes

  let name = "coda-shared-state-test"

  let main () =
    let%bind program_dir = Unix.getcwd () in
    let n = 2 in
    let log = Logger.create () in
    let log = Logger.child log name in
    let transition_interval = 1000.0 in
    let start_margin = Float.to_int (8000.0 /. transition_interval) in
    let max_dist = 5 in
    let snark_worker_public_keys =
      Some [Some Genesis_ledger.high_balance_pk; None]
    in
    Coda_processes.init () ;
    Coda_processes.spawn_local_processes_exn ~transition_interval n
      ~program_dir ~snark_worker_public_keys
      ~should_propose:(fun i -> i = 0)
      ~f:(fun workers ->
        let blocks = ref 0 in
        let%bind () =
          Deferred.List.all_unit
            (List.mapi workers ~f:(fun i worker ->
                 let update_block = ref 0 in
                 let last_balance = ref (Currency.Balance.of_int 0) in
                 let%bind strongest_ledgers =
                   Coda_process.strongest_ledgers_exn worker
                 in
                 let sender_pk = Genesis_ledger.high_balance_pk in
                 let receiver_pk = Genesis_ledger.low_balance_pk in
                 let sender_sk = Genesis_ledger.high_balance_sk in
                 let send_amount = Currency.Amount.of_int 10 in
                 let fee = Currency.Fee.of_int 0 in
                 don't_wait_for
                   (let rec go () =
                      let%bind b =
                        Coda_process.get_balance_exn worker sender_pk
                      in
                      if i = 1 then
                        Logger.trace log
                          !"got balance %{sexp: Currency.Balance.t option}"
                          b ;
                      Option.iter b ~f:(fun b ->
                          if b <> !last_balance then (
                            update_block := !blocks ;
                            last_balance := b ) ) ;
                      let%bind () = after (Time.Span.of_sec 0.5) in
                      go ()
                    in
                    go ()) ;
                 let%bind () =
                   if i = 0 then (
                     Logger.trace log "send transaction" ;
                     Coda_process.send_transaction_exn worker sender_sk
                       receiver_pk send_amount fee )
                   else Deferred.unit
                 in
                 don't_wait_for
                   (Linear_pipe.iter strongest_ledgers ~f:(fun (prev, curr) ->
                        if i = 0 then blocks := !blocks + 1 ;
                        let diff = !blocks - !update_block in
                        assert (diff < max_dist || !blocks < start_margin) ;
                        let%bind () =
                          if !blocks > 20 + start_margin then exit 0
                          else Deferred.unit
                        in
                        let%bind () =
                          if i = 0 then (
                            Logger.trace log "send transaction" ;
                            Coda_process.send_transaction_exn worker sender_sk
                              receiver_pk send_amount fee )
                          else Deferred.unit
                        in
                        return () )) ;
                 Deferred.unit ))
        in
        let%bind () = after (Time.Span.of_sec 1000000.) in
        return () )

  let command =
    Command.async_spec ~summary:"Test that workers share states"
      Command.Spec.(empty)
      main
end
