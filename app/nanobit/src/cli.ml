open Core
open Async
open Nanobit_base
open Blockchain_snark
open Cli_common
open Main

let daemon =
  let open Command.Let_syntax in
  Command.async ~summary:"Current daemon"
    (let%map_open conf_dir =
       flag "config-directory" ~doc:"Configuration directory" (optional file)
     and should_mine = flag "mine" ~doc:"Run the miner" (required bool)
     and port =
       flag "port" ~doc:"Server port for other to connect" (required int16)
     and client_port =
       flag "client-port" ~doc:"Port for client to connect daemon locally"
         (required int16)
     and ip =
       flag "ip" ~doc:"External IP address for others to connect"
         (optional string)
     in
     fun () ->
       let open Deferred.Let_syntax in
       let%bind home = Sys.home_directory () in
       let conf_dir =
         Option.value ~default:(home ^/ ".current-config") conf_dir
       in
       let%bind () = Unix.mkdir ~p:() conf_dir in
       let%bind initial_peers =
         let peers_path = conf_dir ^/ "peers" in
         match%bind
           Reader.load_sexp peers_path [%of_sexp : Host_and_port.t list]
         with
         | Ok ls -> return ls
         | Error e ->
             let default_initial_peers = [] in
             let%map () =
               Writer.save_sexp peers_path
                 ([%sexp_of : Host_and_port.t list] default_initial_peers)
             in
             []
       in
       let log = Logger.create () in
       let%bind ip =
         match ip with None -> Find_ip.find () | Some ip -> return ip
       in
       let remap_addr_port = Fn.id in
       let me = Host_and_port.create ~host:ip ~port in
       let%bind prover = Prover.create ~conf_dir in
       let%bind genesis_proof =
         Prover.genesis_proof prover >>| Or_error.ok_exn
       in
       let module Init = struct
         type proof = Proof.Stable.V1.t [@@deriving bin_io]

         let conf_dir = conf_dir

         let prover = prover

         let genesis_proof = genesis_proof

         let fee_public_key = Genesis_ledger.rich_pk
       end in
       let module Main = ( val if Insecure.key_generation then ( module Main_without_snark
                                                                          (Init)
                                 : Main_intf )
                               else
                                 (module Main_with_snark (Storage.Disk) (Init)
                                 : Main_intf ) ) in
       let module Run = Run (Main) in
       let%bind () =
         let open Main in
         let net_config =
           { Inputs.Net.Config.parent_log= log
           ; gossip_net_params=
               { timeout= Time.Span.of_sec 1.
               ; target_peer_count= 8
               ; address= remap_addr_port me }
           ; initial_peers
           ; me
           ; remap_addr_port }
         in
         let%map minibit =
           Main.create
             { log
             ; net_config
             ; ledger_disk_location= conf_dir ^/ "ledgers"
             ; pool_disk_location= conf_dir ^/ "transaction_pool" }
         in
         Run.setup_client_server ~minibit ~client_port ~log ;
         Run.run ~minibit ~log
       in
       Async.never ())

let () =
  Random.self_init () ;
  Command.group ~summary:"Current"
    [ ("daemon", daemon)
    ; (Parallel.worker_command_name, Parallel.worker_command)
    ; ("full-test", Full_test.command)
    ; ("client", Client.command)
    ; ("transaction-snark-profiler", Transaction_snark_profiler.command) ]
  |> Command.run

let () = never_returns (Scheduler.go ())
