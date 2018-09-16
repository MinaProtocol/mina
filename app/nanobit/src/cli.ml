open Core
open Async
open Nanobit_base
open Blockchain_snark
open Cli_lib
open Coda_main
module Git_sha = Client_lib.Git_sha

let commit_id = Option.map [%getenv "CODA_COMMIT_SHA1"] ~f:Git_sha.of_string

let force_updates = false

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
  Command.async ~summary:"Coda daemon"
    (let%map_open conf_dir =
       flag "config-directory" ~doc:"DIR Configuration directory"
         (optional file)
     and should_propose_flag =
       flag "propose" ~doc:"true|false Run the proposer (default:true)"
         (optional bool)
     and peers =
       flag "peer"
         ~doc:
           "HOST:PORT TCP daemon communications (can be given multiple times)"
         (listed peer)
     and run_snark_worker_flag =
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
     and rest_server_port =
       flag "rest-port"
         ~doc:
           "PORT local REST-server for daemon interaction (default no \
            rest-server)"
         (optional int16)
     and ip =
       flag "ip" ~doc:"IP External IP address for others to connect"
         (optional string)
     and transaction_capacity_log_2 =
       flag "txn-capacity"
         ~doc:
           "CAPACITY_LOG_2 Log of capacity of transactions per transition \
            (default: 4)"
         (optional int)
     and proposal_interval =
       flag "proposal-interval"
         ~doc:
           "MILLIS Time between the proposer proposing and waiting (default: \
            5000)"
         (optional int)
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
       let should_propose_flag =
         Option.value ~default:true should_propose_flag
       in
       let transaction_capacity_log_2 =
         Option.value ~default:4 transaction_capacity_log_2
       in
       let proposal_interval =
         Option.value ~default:(Time.Span.of_ms 5000.)
           (Option.map proposal_interval ~f:(fun millis ->
                Int.to_float millis |> Time.Span.of_ms ))
       in
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
       let keypair =
         Signature_lib.Keypair.of_private_key_exn
           Genesis_ledger.high_balance_sk
       in
       let module Config = struct
         let logger = log

         let conf_dir = conf_dir

         let lbc_tree_max_depth = `Finite 50

         let transition_interval = proposal_interval

         let keypair = keypair

         let genesis_proof = Precomputed_values.base_proof

         let transaction_capacity_log_2 = transaction_capacity_log_2

         let commit_id = commit_id
       end in
       let%bind (module Init) = make_init (module Config) (module Kernel) in
       let module M = Coda.Make (Init) () in
       let module Run = Run (Config) (M) in
       let%bind () =
         let open M in
         let run_snark_worker_action =
           Option.value_map run_snark_worker_flag ~default:`Don't_run ~f:
             (fun k -> `With_public_key k )
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
             (Run.Config.make ~log ~net_config
                ~should_propose:should_propose_flag
                ~run_snark_worker:(Option.is_some run_snark_worker_flag)
                ~ledger_builder_persistant_location:
                  (conf_dir ^/ "ledger_builder")
                ~transaction_pool_disk_location:(conf_dir ^/ "transaction_pool")
                ~snark_pool_disk_location:(conf_dir ^/ "snark_pool")
                ~time_controller:(Inputs.Time.Controller.create ())
                ~keypair ())
         in
         don't_wait_for (Linear_pipe.drain (Run.strongest_ledgers minibit)) ;
         Run.setup_local_server ?rest_server_port ~minibit ~client_port ~log () ;
         Run.run_snark_worker ~log ~client_port run_snark_worker_action
       in
       Async.never ())

let () =
  Random.self_init () ;
  let exit1 ?msg =
    match msg with
    | None -> Core.exit 1
    | Some msg ->
        Core.Printf.eprintf "%s\n" msg ;
        Core.exit 1
  in
  let rec ensure_testnet_id_still_good () =
    if force_updates then
      let open Cohttp_async in
      let%bind resp, body =
        Client.get (Uri.of_string "http://updates.o1test.net/testnet_id")
      in
      let%map body_string = Body.to_string body in
      (* Maybe the Git_sha.of_string is a bit gratuitous *)
      let remote_id = Git_sha.of_string @@ String.strip body_string in
      let finish local_id remote_id =
        let str x = Git_sha.sexp_of_t x |> Sexp.to_string in
        exit1
          ~msg:
            (sprintf
               "The version for the testnet has changed. I am %s, I should be \
                %s. Please download the latest Coda software at \
                https://github.com/codaprotocol/coda/releases"
               ( local_id |> Option.map ~f:str
               |> Option.value ~default:"[COMMIT_SHA1 not set]" )
               (str remote_id))
      in
      match commit_id with
      | None -> finish None remote_id
      | Some sha when Git_sha.equal sha remote_id ->
          Async.Clock.run_after (Time.Span.of_hr 1.0)
            (fun () -> don't_wait_for @@ ensure_testnet_id_still_good ())
            ()
      | Some _ -> finish commit_id remote_id
    else Deferred.unit
  in
  ensure_testnet_id_still_good () |> don't_wait_for ;
  let env name ~f ~default =
    let name = Printf.sprintf "CODA_%s" name in
    Unix.getenv name
    |> Option.map ~f:(fun x ->
           match f @@ String.uppercase x with
           | Some v -> v
           | None ->
               exit1
                 ~msg:
                   (Printf.sprintf
                      "Inside env var %s, there was a value I don't \
                       understand \"%s\""
                      name x) )
    |> Option.value ~default
  in
  let commands =
    let consensus_mechanism =
      env "CONSENSUS_MECHANISM" ~default:`Proof_of_signature ~f:(function
        | "PROOF_OF_SIGNATURE" -> Some `Proof_of_signature
        | "PROOF_OF_STAKE" -> Some `Proof_of_stake
        | _ -> None )
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
              module Time = Nanobit_base.Block_time

              let proposal_interval =
                env "PROPOSAL_INTERVAL"
                  ~default:(Time.Span.of_ms @@ Int64.of_int 5000)
                  ~f:(fun str ->
                    try Some (Time.Span.of_ms @@ Int64.of_string str)
                    with _ -> None )
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
              let genesis_state_timestamp =
                Core.Time.of_date_ofday
                  (Core.Time.Zone.of_utc_offset ~hours:(-7))
                  (Core.Date.create_exn ~y:2018 ~m:Month.Sep ~d:1)
                  (Core.Time.Ofday.create ~hr:10 ())
                |> Time.of_time

              let genesis_ledger = Nanobit_base.Genesis_ledger.ledger

              let genesis_ledger_total_currency =
                Nanobit_base.Genesis_ledger.total_currency

              let genesis_state_timestamp =
                let default =
                  Core.Time.of_date_ofday
                    (Core.Time.Zone.of_utc_offset ~hours:(-7))
                    (Core.Date.create_exn ~y:2018 ~m:Month.Sep ~d:1)
                    (Core.Time.Ofday.create ~hr:10 ())
                  |> Time.of_time
                in
                env "GENESIS_STATE_TIMESTAMP" ~default ~f:(fun str ->
                    try Some (Time.of_time @@ Core.Time.of_string str)
                    with _ -> None )

              let coinbase =
                env "COINBASE" ~default:(Currency.Amount.of_int 20) ~f:
                  (fun str ->
                    try Some (Currency.Amount.of_int @@ Int.of_string str)
                    with _ -> None )

              let slot_interval =
                env "SLOT_INTERVAL"
                  ~default:(Time.Span.of_ms (Int64.of_int 5000))
                  ~f:(fun str ->
                    try Some (Time.Span.of_ms @@ Int64.of_string str)
                    with _ -> None )

              let unforkable_transition_count =
                env "UNFORKABLE_TRANSITION_COUNT" ~default:12 ~f:(fun str ->
                    try Some (Int.of_string str) with _ -> None )

              let probable_slots_per_transition_count =
                env "PROBABLE_SLOTS_PER_TRANSITION_COUNT" ~default:8 ~f:
                  (fun str -> try Some (Int.of_string str) with _ -> None )

              (* Conservatively pick 1seconds *)
              let expected_network_delay =
                env "EXPECTED_NETWORK_DELAY"
                  ~default:(Time.Span.of_ms (Int64.of_int 1000))
                  ~f:(fun str ->
                    try Some (Time.Span.of_ms @@ Int64.of_string str)
                    with _ -> None )

              let approximate_network_diameter =
                env "APPROXIMATE_NETWORK_DIAMETER" ~default:3 ~f:(fun str ->
                    try Some (Int.of_string str) with _ -> None )
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
          let module Coda_transitive_peers_test =
            Coda_transitive_peers_test.Make (Ledger_proof.Prod) (Kernel) (Coda) in
          [ (Coda_peers_test.name, Coda_peers_test.command)
          ; ( Coda_block_production_test.name
            , Coda_block_production_test.command )
          ; (Coda_shared_state_test.name, Coda_shared_state_test.command)
          ; ( Coda_transitive_peers_test.name
            , Coda_transitive_peers_test.command )
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
          let module Coda_transitive_peers_test =
            Coda_transitive_peers_test.Make (Ledger_proof.Debug) (Kernel)
              (Coda) in
          let group =
            Command.group ~summary:"Integration tests"
              [ (Coda_peers_test.name, Coda_peers_test.command)
              ; ( Coda_block_production_test.name
                , Coda_block_production_test.command )
              ; (Coda_shared_state_test.name, Coda_shared_state_test.command)
              ; ( Coda_transitive_peers_test.name
                , Coda_transitive_peers_test.command )
              ; (Coda_shared_prefix_test.name, Coda_shared_prefix_test.command)
              ; ("full-test", Full_test.command (module Kernel) (module Coda))
              ; ( "transaction-snark-profiler"
                , Transaction_snark_profiler.command ) ]
          in
          [("integration-tests", group)]
      else [] )
  in
  let internal_commands =
    [ ( Snark_worker_lib.Debug.command_name
      , Snark_worker_lib.Debug.Worker.command )
    ; (Snark_worker_lib.Prod.command_name, Snark_worker_lib.Prod.Worker.command)
    ]
  in
  Command.group ~summary:"Coda"
    ( [ ( "internal"
        , Command.group ~summary:"Internal commands" internal_commands )
      ; (Parallel.worker_command_name, Parallel.worker_command)
      ; ("client", Client.command) ]
    @ commands )
  |> Command.run

let () = never_returns (Scheduler.go ())
