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

module type Consensus_mechanism_intf = sig
  module Make (Ledger_builder_diff : sig
    type t [@@deriving bin_io, sexp]
  end) :
    Consensus.Mechanism.S
    with type Internal_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
     and type External_transition.Ledger_builder_diff.t = Ledger_builder_diff.t
end

let default_external_port = 8302

let daemon (type ledger_proof) (module Kernel
    : Kernel_intf with type Ledger_proof.t = ledger_proof) (module Coda
    : Coda_intf with type ledger_proof = ledger_proof) =
  let open Command.Let_syntax in
  Command.async ~summary:"Current daemon"
    (let%map_open conf_dir =
       flag "config-directory" ~doc:"DIR Configuration directory"
         (optional file)
     and should_propose =
       flag "propose" ~doc:"true|false Run the proposer (default:true)"
         (optional bool)
     and peers =
       flag "peer"
         ~doc:
           "HOST:PORT TCP daemon communications (can be given multiple times)"
         (listed peer)
     and run_snark_worker =
       flag "run-snark-worker" ~doc:"KEY Run the SNARK worker with a key"
         (optional public_key_compressed)
     and external_port =
       flag "external-port"
         ~doc:
           (Printf.sprintf
              "PORT Base server port for daemon TCP (discovery UDP on port+1) \
               (default: %d)"
              default_external_port)
         (optional int16)
     and client_port =
       flag "client-port"
         ~doc:
           (Printf.sprintf
              "PORT Client to daemon local communication (default: %d)"
              default_client_port)
         (optional int16)
     and ip =
       flag "ip" ~doc:"IP External IP address for others to connect"
         (optional string)
     in
     fun () ->
       Parallel.init_master () ;
       let open Deferred.Let_syntax in
       let%bind home = Sys.home_directory () in
       let conf_dir =
         Option.value ~default:(home ^/ ".current-config") conf_dir
       in
       let external_port =
         Option.value ~default:default_external_port external_port
       in
       let client_port =
         Option.value ~default:default_client_port client_port
       in
       let should_propose = Option.value ~default:true should_propose in
       let discovery_port = external_port + 1 in
       let%bind () = Unix.mkdir ~p:() conf_dir in
       let%bind initial_peers =
         match peers with
         | _ :: _ -> return peers
         | [] ->
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
       let me =
         (Host_and_port.create ~host:ip ~port:discovery_port, external_port)
       in
       let module Config = struct
         let logger = log

         let conf_dir = conf_dir

         let lbc_tree_max_depth = `Finite 50

         let transition_interval = Time.Span.of_sec 5.0

         let fee_public_key = Genesis_ledger.high_balance_pk

         let genesis_proof = Precomputed_values.base_proof
       end in
       let%bind (module Init) = make_init (module Config) (module Kernel) in
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
               ; initial_peers
               ; me } }
         in
         let%map minibit =
           Run.create
             (Run.Config.make ~log ~net_config ~should_propose
                ~ledger_builder_persistant_location:
                  (conf_dir ^/ "ledger_builder")
                ~transaction_pool_disk_location:(conf_dir ^/ "transaction_pool")
                ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                ~time_controller:(Inputs.Time.Controller.create ())
                ())
         in
         don't_wait_for (Linear_pipe.drain (Run.strongest_ledgers minibit)) ;
         Run.setup_local_server ~minibit ~client_port ~log ;
         Run.run_snark_worker ~log ~client_port run_snark_worker
       in
       Async.never ())

let () =
  let commands =
    let consensus_mechanism_of_string = function
      | "PROOF_OF_SIGNATURE" -> `Proof_of_signature
      | "PROOF_OF_STAKE" -> `Proof_of_stake
      | _ -> failwith "invalid consensus mechanism"
    in
    let consensus_mechanism =
      Unix.getenv "CODA_CONSENSUS_MECHANISM"
      |> Option.map
           ~f:(Fn.compose consensus_mechanism_of_string String.uppercase)
      |> Option.value ~default:`Proof_of_signature
    in
    let (module Consensus_mechanism : Consensus_mechanism_intf) =
      match consensus_mechanism with
      | `Proof_of_signature ->
          ( module struct
            module Make (Ledger_builder_diff : sig
              type t [@@deriving sexp, bin_io]
            end) =
            Consensus.Proof_of_signature.Make (struct
              module Proof = Nanobit_base.Proof
              module Ledger_builder_diff = Ledger_builder_diff
            end)
          end )
      | `Proof_of_stake ->
          ( module struct
            module Make (Ledger_builder_diff : sig
              type t [@@deriving sexp, bin_io]
            end) =
            Consensus.Proof_of_stake.Make (struct
              module Proof = Nanobit_base.Proof
              module Ledger_builder_diff = Ledger_builder_diff
              module Time = Nanobit_base.Block_time

              (* TODO: choose reasonable values *)
              let genesis_state_timestamp = Time.now ()

              let genesis_ledger_total_currency =
                Nanobit_base.Genesis_ledger.total_currency

              let genesis_ledger = Nanobit_base.Genesis_ledger.ledger

              let coinbase = Currency.Amount.of_int 20

              let slot_interval = Time.Span.of_ms (Int64.of_int 500)

              let unforkable_transition_count = 12

              let probable_slots_per_transition_count = 8
            end)
          end )
    in
    if Insecure.with_snark then
      let module Kernel =
        Make_kernel (Ledger_proof.Prod) (Consensus_mechanism.Make) in
      let module Coda = struct
        type ledger_proof = Transaction_snark.t

        module Make
            (Init : Init_intf with type Ledger_proof.t = Transaction_snark.t)
            () =
          Coda_with_snark (Storage.Disk) (Init) ()
      end in
      ("daemon", daemon (module Kernel) (module Coda))
      ::
      ( if Insecure.integration_tests then
          let module Coda_peers_test =
            Coda_peers_test.Make (Ledger_proof.Prod) (Kernel) (Coda) in
          let module Coda_block_production_test =
            Coda_block_production_test.Make (Ledger_proof.Prod) (Kernel) (Coda) in
          let module Coda_shared_prefix_test =
            Coda_shared_prefix_test.Make (Ledger_proof.Prod) (Kernel) (Coda) in
          let module Coda_shared_state_test =
            Coda_shared_state_test.Make (Ledger_proof.Prod) (Kernel) (Coda) in
          [ (Coda_peers_test.name, Coda_peers_test.command)
          ; ( Coda_block_production_test.name
            , Coda_block_production_test.command )
          ; (Coda_shared_state_test.name, Coda_shared_state_test.command)
          ; (Coda_shared_prefix_test.name, Coda_shared_prefix_test.command)
          ; ("full-test", Full_test.command (module Kernel) (module Coda)) ]
      else [] )
    else
      let module Kernel =
        Make_kernel (Ledger_proof.Debug) (Consensus_mechanism.Make) in
      let module Coda = struct
        type ledger_proof = Ledger_proof.Debug.t

        module Make
            (Init : Init_intf with type Ledger_proof.t = Ledger_proof.Debug.t)
            () =
          Coda_without_snark (Init) ()
      end in
      ("daemon", daemon (module Kernel) (module Coda))
      ::
      ( if Insecure.integration_tests then
          let module Coda_peers_test =
            Coda_peers_test.Make (Ledger_proof.Debug) (Kernel) (Coda) in
          let module Coda_block_production_test =
            Coda_block_production_test.Make (Ledger_proof.Debug) (Kernel)
              (Coda) in
          let module Coda_shared_prefix_test =
            Coda_shared_prefix_test.Make (Ledger_proof.Debug) (Kernel) (Coda) in
          let module Coda_shared_state_test =
            Coda_shared_state_test.Make (Ledger_proof.Debug) (Kernel) (Coda) in
          [ (Coda_peers_test.name, Coda_peers_test.command)
          ; ( Coda_block_production_test.name
            , Coda_block_production_test.command )
          ; (Coda_shared_state_test.name, Coda_shared_state_test.command)
          ; (Coda_shared_prefix_test.name, Coda_shared_prefix_test.command)
          ; ("full-test", Full_test.command (module Kernel) (module Coda)) ]
      else [] )
  in
  let extra_commands =
    if Insecure.integration_tests then
      [("transaction-snark-profiler", Transaction_snark_profiler.command)]
    else []
  in
  Random.self_init () ;
  Command.group ~summary:"Current"
    ( [ (Parallel.worker_command_name, Parallel.worker_command)
      ; ( Snark_worker_lib.Debug.command_name
        , Snark_worker_lib.Debug.Worker.command )
      ; ( Snark_worker_lib.Prod.command_name
        , Snark_worker_lib.Prod.Worker.command )
      ; ("client", Client.command) ]
    @ commands @ extra_commands )
  |> Command.run

let () = never_returns (Scheduler.go ())
