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
    let external_ports = List.init n ~f:(fun i -> 23000 + (i * 2)) in
    let discovery_ports = List.init n ~f:(fun i -> 23000 + 1 + (i * 2)) in
    let all_peers =
      List.map discovery_ports ~f:(fun p -> Host_and_port.create "127.0.0.1" p)
    in
    let peers =
      List.init n ~f:(fun i ->
          List.take all_peers i @ List.drop all_peers (i + 1) )
    in
    (discovery_ports, external_ports, peers)

  let spawn_local_processes_exn ?(transition_interval= 1000.0)
      ?proposal_interval ?(should_propose= Fn.const true) ?(first_delay= 3.0) n
      ~program_dir ~snark_worker_public_keys ~f =
    let fns =
      let discovery_ports, external_ports, peers = net_configs n in
      let peers = [] :: List.drop peers 1 in
      let args =
        List.map3_exn discovery_ports external_ports peers ~f:(fun x y z ->
            (x, y, z) )
      in
      List.mapi args ~f:(fun i (discovery_port, external_port, peers) ->
          let public_key =
            Option.map snark_worker_public_keys ~f:(fun keys ->
                List.nth_exn keys i )
          in
          let snark_worker_config =
            Option.bind public_key ~f:(fun public_key ->
                Option.bind public_key ~f:(fun public_key ->
                    Some
                      { Coda_process.Coda_worker.Snark_worker_config.public_key
                      ; port= 20000 + i } ) )
          in
          Coda_process.spawn_local_exn ?proposal_interval ~peers
            ~discovery_port ~external_port ~snark_worker_config ~program_dir
            ~should_propose:(should_propose i) () )
    in
    let first = List.hd_exn fns in
    let rest = List.drop fns 1 in
    let scoped =
      List.fold (List.rev rest)
        ~init:(fun ws -> f (List.rev ws))
        ~f:(fun last fn ws -> fn (fun w -> last (w :: ws)))
    in
    first (fun w ->
        let%bind () = after (Time.Span.of_sec first_delay) in
        scoped [w] )
end
