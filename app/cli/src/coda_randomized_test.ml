open Core
open Async
open Coda_worker
open Coda_main
open Coda_base
open Signature_lib

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) :
  Integration_test_intf.S =
struct
  module Coda_processes = Coda_processes.Make (Ledger_proof) (Kernel) (Coda)
  open Coda_processes
  module Coda_worker_testnet =
    Coda_worker_testnet.Make (Ledger_proof) (Kernel) (Coda)

  let name = "coda-randomized-test"

  let main () =
    let log = Logger.create () in
    let log = Logger.child log name in
    let n = 5 in
    let should_propose i = i = 0 in
    let accounts = Genesis_ledger.extra_accounts in
    let snark_work_public_keys i = Some (fst (List.nth_exn accounts i)) in
    let%bind testnet =
      Coda_worker_testnet.test log n should_propose snark_work_public_keys
    in
    Coda_worker_testnet.Api.run testnet log
      [ Wait 5.
      ; Stop 1
      ; Send (0, 
              Genesis_ledger.high_balance_sk, 
              Genesis_ledger.low_balance_pk, 
              10, 0)
      ; Wait 5.
      ; Start 1
      ; Wait 20.
      ]

  let command =
    Command.async_spec
      ~summary:"Test of random behavior given a seed"
      Command.Spec.(empty)
      main
end

