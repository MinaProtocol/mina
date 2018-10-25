open Core
open Async
open Coda_worker
open Coda_main

module Make (Kernel : Kernel_intf) : Integration_test_intf.S = struct
  let name = "coda-transitive-peers-test"

  module Coda_processes = Coda_processes.Make (Kernel)
  open Coda_processes

  let main () =
    let%bind program_dir = Unix.getcwd () in
    let n = 3 in
    let log = Logger.create () in
    let log = Logger.child log name in
    let work_selection = Protocols.Coda_pow.Work_selection.Seq in
    Coda_processes.init () ;
    let configs =
      Coda_processes.local_configs n ~program_dir
        ~snark_worker_public_keys:None ~should_propose:(Fn.const false)
        ~work_selection
    in
    let%bind workers = Coda_processes.spawn_local_processes_exn configs in
    let discovery_ports, external_ports, peers =
      Coda_processes.net_configs (n + 1)
    in
    let expected_peers = List.nth_exn peers n in
    let peers = [List.hd_exn expected_peers] in
    let external_port = List.nth_exn external_ports n in
    let discovery_port = List.nth_exn discovery_ports n in
    Logger.debug log
      !"connecting to peers %{sexp: Host_and_port.t list}\n"
      peers ;
    let config =
      Coda_process.local_config ~peers ~external_port ~discovery_port
        ~snark_worker_config:None ~should_propose:false ~program_dir
        ~work_selection ()
    in
    let%bind worker = Coda_process.spawn_exn config in
    let%bind _ = after (Time.Span.of_sec 10.) in
    let%map peers = Coda_process.peers_exn worker in
    Logger.debug log
      !"got peers %{sexp: Kademlia.Peer.t list} %{sexp: Host_and_port.t list}\n"
      peers expected_peers ;
    let module S = Host_and_port.Set in
    assert (
      S.equal (S.of_list (peers |> List.map ~f:fst)) (S.of_list expected_peers)
    )

  let command =
    Command.async_spec ~summary:"Simple use of Async Rpc_parallel V2"
      Command.Spec.(empty)
      main
end
