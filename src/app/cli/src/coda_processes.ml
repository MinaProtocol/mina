open Core
open Async
open Coda_worker
open Coda_main

module Make (Kernel : Kernel_intf) = struct
  module Coda_process = Coda_process.Make (Kernel)

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

  let local_configs ?(transition_interval = 1000.0) ?proposal_interval
      ?(should_propose = Fn.const true) n ~program_dir
      ~snark_worker_public_keys ~work_selection =
    let discovery_ports, external_ports, peers = net_configs n in
    let peers = [] :: List.drop peers 1 in
    let args =
      List.map3_exn discovery_ports external_ports peers ~f:(fun x y z ->
          (x, y, z) )
    in
    let configs =
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
          Coda_process.local_config ?proposal_interval ~peers ~discovery_port
            ~external_port ~snark_worker_config ~program_dir
            ~transition_interval ~should_propose:(should_propose i)
            ~work_selection () )
    in
    configs

  let spawn_local_processes_exn ?(first_delay = 3.0) configs =
    let first = List.hd_exn configs in
    let rest = List.drop configs 1 in
    let%bind first = Coda_process.spawn_exn first in
    let%bind () = after (Time.Span.of_sec first_delay) in
    let%map rest =
      Deferred.List.all (List.map rest ~f:(fun c -> Coda_process.spawn_exn c))
    in
    first :: rest
end
