open Core
open Async
open Coda_worker
open Coda_main

module Make
    (Ledger_proof : Ledger_proof_intf)
    (Kernel : Kernel_intf with type Ledger_proof.t = Ledger_proof.t)
    (Coda : Coda_intf.S with type ledger_proof = Ledger_proof.t) =
struct
  module Coda_process = Coda_process.Make (Ledger_proof) (Kernel) (Coda)

  let init () = Parallel.init_master ()

  let net_configs n =
    let ports = List.init n ~f:(fun i -> 23000 + i) in
    let gossip_ports = List.init n ~f:(fun i -> 24000 + i) in
    let all_peers =
      List.map ports ~f:(fun p -> Host_and_port.create "127.0.0.1" p)
    in
    let peers =
      List.init n ~f:(fun i ->
          List.take all_peers i @ List.drop all_peers (i + 1) )
    in
    (ports, gossip_ports, peers)

  let spawn_local_processes_exn n ~program_dir ~f =
    let fns =
      let ports, gossip_ports, peers = net_configs n in
      let peers = [] :: List.drop peers 1 in
      List.map3_exn ports gossip_ports peers ~f:(fun port gossip_port peers ->
          Coda_process.spawn_local_exn ~peers ~port ~gossip_port ~program_dir
      )
    in
    let first = List.hd_exn fns in
    let rest = List.drop fns 1 in
    let scoped =
      List.fold (List.rev rest)
        ~init:(fun ws -> f (List.rev ws))
        ~f:(fun last fn ws -> fn (fun w -> last (w :: ws)))
    in
    first (fun w ->
        let%bind () = after (Time.Span.of_sec 3.) in
        scoped [w] )
end
