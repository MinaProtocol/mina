open Core
open Async
open Nanobit_base
open Blockchain_snark
open Cli_lib
open Coda_main

module type Coda_intf = sig
  type ledger_proof

  module Make (Init : Init_intf with type Ledger_proof.t = ledger_proof) () :
    Main_intf
end

let daemon (type ledger_proof) (module Kernel
    : Kernel_intf with type Ledger_proof.t = ledger_proof) (module Coda
    : Coda_intf with type ledger_proof = ledger_proof) =
  let open Command.Let_syntax in
  Command.async ~summary:"Current daemon"
    (let%map_open conf_dir =
       flag "config-directory" ~doc:"Configuration directory" (optional file)
     and should_mine = flag "mine" ~doc:"Run the miner" (optional bool)
     and run_snark_worker =
       flag "run-snark-worker" ~doc:"Run the SNARK worker"
         (optional public_key_compressed)
     and port =
       flag "port"
         ~doc:
           (Printf.sprintf "Server port for other to connect (default: %d)"
              default_daemon_port)
         (optional int16)
     and client_port =
       flag "client-port"
         ~doc:"Port for client to connect daemon locally (default: 8301)"
         (optional int16)
     and membership_port =
       flag "membership-port"
         ~doc:
           "Port for dameon to find out the membership topology (default: 8303)"
         (optional int16)
     and ip =
       flag "ip" ~doc:"External IP address for others to connect"
         (optional string)
     in
     fun () ->
       Parallel.init_master () ;
       let open Deferred.Let_syntax in
       let%bind home = Sys.home_directory () in
       let conf_dir =
         Option.value ~default:(home ^/ ".current-config") conf_dir
       in
       let port = Option.value ~default:default_daemon_port port in
       let client_port = Option.value ~default:8301 client_port in
       let membership_port = Option.value ~default:8303 membership_port in
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
       let me = Host_and_port.create ~host:ip ~port in
       let module Config = struct
         let logger = log

         let conf_dir = conf_dir

         let lbc_tree_max_depth = `Finite 50

         let transaction_interval = Time.Span.of_sec 5.0

         let fee_public_key = Genesis_ledger.rich_pk

         let genesis_proof = Precomputed_values.base_proof
       end in
       let (module Init) = make_init (module Config) (module Kernel) in
       let module M = Coda.Make (Init) () in
       let module Run = Run (M) in
       let%bind () =
         let open M in
         let run_snark_worker =
           Option.value_map run_snark_worker ~default:`Don't_run ~f:(fun k ->
               `With_public_key k )
         in
         let net_config =
           { Inputs.Net.Config.parent_log= log
           ; gossip_net_params=
               { timeout= Time.Span.of_sec 1.
               ; parent_log= log
               ; target_peer_count= 8
               ; conf_dir
               ; address= Host_and_port.create ~host:ip ~port:membership_port
               ; initial_peers
               ; me } }
         in
         let%map minibit =
           Run.create
             (Run.Config.make ~log ~net_config
                ~ledger_builder_persistant_location:
                  (conf_dir ^/ "ledger_builder")
                ~transaction_pool_disk_location:(conf_dir ^/ "transaction_pool")
                ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                ~time_controller:(Inputs.Time.Controller.create ())
                ())
         in
         Run.setup_local_server ~minibit ~client_port ~log ;
         Run.run_snark_worker ~log ~client_port run_snark_worker
       in
       Async.never ())

let () =
  let daemon, full_test =
    if Insecure.with_snark then
      let module Kernel = Kernel.Prod () in
      let module Coda = struct
        type ledger_proof = Transaction_snark.t

        module Make
            (Init : Init_intf with type Ledger_proof.t = Transaction_snark.t)
            () =
          Coda_with_snark (Storage.Disk) (Init) ()
      end in
      ( daemon (module Kernel) (module Coda)
      , Full_test.command (module Kernel) (module Coda) )
    else
      let module Kernel = Kernel.Debug () in
      let module Coda = struct
        type ledger_proof = Ledger_proof_statement.t

        module Make
            (Init : Init_intf
                    with type Ledger_proof.t = Ledger_proof_statement.t)
            () =
          Coda_without_snark (Init) ()
      end in
      ( daemon (module Kernel) (module Coda)
      , Full_test.command (module Kernel) (module Coda) )
  in
  Random.self_init () ;
  Command.group ~summary:"Current"
    [ ("daemon", daemon)
    ; (Parallel.worker_command_name, Parallel.worker_command)
    ; ( Snark_worker_lib.Debug.command_name
      , Snark_worker_lib.Debug.Worker.command )
    ; (Snark_worker_lib.Prod.command_name, Snark_worker_lib.Prod.Worker.command)
    ; ("full-test", full_test)
    ; ("client", Client.command)
    ; ("transaction-snark-profiler", Transaction_snark_profiler.command)
    ; (Coda_sample_test.name, Coda_sample_test.command)
    ; (Coda_block_production_test.name, Coda_block_production_test.command)
    ; (Coda_peers_test.name, Coda_peers_test.command) ]
  |> Command.run

let () = never_returns (Scheduler.go ())
