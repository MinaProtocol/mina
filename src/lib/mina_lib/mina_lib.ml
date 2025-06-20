open Core
open Async
open Mina_base
open Mina_transaction
module Ledger = Mina_ledger.Ledger
open Mina_block
open Pipe_lib
open Strict_pipe
open Signature_lib
module Archive_client = Archive_client
module Config = Config
module Conf_dir = Conf_dir
module Subscriptions = Mina_subscriptions
module Snark_worker_lib = Snark_worker
module Timeout = Timeout_lib.Core_time

let daemon_start_time = Time_ns.now ()

type Structured_log_events.t += Connecting
  [@@deriving register_event { msg = "Mina daemon is connecting" }]

type Structured_log_events.t += Listening
  [@@deriving register_event { msg = "Mina daemon is listening" }]

type Structured_log_events.t += Bootstrapping
  [@@deriving register_event { msg = "Mina daemon is bootstrapping" }]

type Structured_log_events.t += Ledger_catchup
  [@@deriving register_event { msg = "Mina daemon is doing ledger catchup" }]

type Structured_log_events.t += Synced
  [@@deriving register_event { msg = "Mina daemon is synced" }]

type Structured_log_events.t +=
  | Rebroadcast_transition of { state_hash : State_hash.t }
  [@@deriving register_event { msg = "Rebroadcasting $state_hash" }]

exception Snark_worker_error of int

exception Snark_worker_signal_interrupt of Signal.t

(* A way to run a single snark worker for a daemon in a lazy manner. Forcing
   this lazy value will run the snark worker process. A snark work is
   assigned to a public key. This public key can change throughout the entire time
   the daemon is running *)
type snark_worker =
  { public_key : Public_key.Compressed.t
  ; process : Process.t Ivar.t
  ; kill_ivar : unit Ivar.t
  }

type processes =
  { prover : Prover.t
  ; verifier : Verifier.t
  ; vrf_evaluator : Vrf_evaluator.t
  ; mutable snark_worker :
      [ `On of snark_worker * Currency.Fee.t | `Off of Currency.Fee.t ]
  ; uptime_snark_worker_opt : Uptime_service.Uptime_snark_worker.t option
  }

type components =
  { net : Mina_networking.t
  ; transaction_pool : Network_pool.Transaction_pool.t
  ; snark_pool : Network_pool.Snark_pool.t
  ; transition_frontier : Transition_frontier.t option Broadcast_pipe.Reader.t
  ; most_recent_valid_block :
      Mina_block.initial_valid_header Broadcast_pipe.Reader.t
  ; block_produced_bvar : (Transition_frontier.Breadcrumb.t, read_write) Bvar.t
  }

(* tag commands so they can share a common pipe, to ensure sequentiality of nonces *)
type command_inputs =
  | Signed_command_inputs of User_command_input.t list
  | Zkapp_command_command_inputs of Zkapp_command.Stable.Latest.t list

type pipes =
  { validated_transitions_reader : Mina_block.Validated.t Strict_pipe.Reader.t
  ; producer_transition_writer :
      ( Transition_frontier.Breadcrumb.t
      , Strict_pipe.synchronous
      , unit Deferred.t )
      Strict_pipe.Writer.t
  ; user_command_input_writer :
      ( command_inputs
        * (   ( [ `Broadcasted | `Not_broadcasted ]
              * Network_pool.Transaction_pool.Resource_pool.Diff.t
              * Network_pool.Transaction_pool.Resource_pool.Diff.Rejected.t )
              Or_error.t
           -> unit )
        * (   Account_id.t
           -> ( [ `Min of Mina_base.Account.Nonce.t ] * Mina_base.Account.Nonce.t
              , string )
              Result.t )
        * (Account_id.t -> Account.t option Participating_state.T.t)
      , Strict_pipe.synchronous
      , unit Deferred.t )
      Strict_pipe.Writer.t
  ; tx_local_sink : Network_pool.Transaction_pool.Local_sink.t
  ; snark_local_sink : Network_pool.Snark_pool.Local_sink.t
  }

type t =
  { config : Config.t
  ; processes : processes
  ; components : components
  ; initialization_finish_signal : unit Ivar.t
  ; pipes : pipes
  ; wallets : Secrets.Wallets.t
  ; coinbase_receiver : Consensus.Coinbase_receiver.t ref
  ; snark_job_state : Work_selector.State.t
  ; mutable next_producer_timing :
      Daemon_rpcs.Types.Status.Next_producer_timing.t option
  ; subscriptions : Mina_subscriptions.t
  ; sync_status : Sync_status.t Mina_incremental.Status.Observer.t
  ; precomputed_block_writer :
      ([ `Path of string ] option * [ `Log ] option) ref
  ; block_production_status :
      [ `Producing | `Producing_in_ms of float | `Free ] ref
  ; in_memory_reverse_structured_log_messages_for_integration_test :
      (int * string list * bool) ref
  ; vrf_evaluation_state : Block_producer.Vrf_evaluation_state.t
  ; commit_id : string
  ; proof_cache_db : Proof_cache_tag.cache_db
  }
[@@deriving fields]

let vrf_evaluation_state t = t.vrf_evaluation_state

let time_controller t = t.config.time_controller

let subscription t = t.subscriptions

let commit_id t = t.commit_id

let compile_config t = t.config.compile_config

let peek_frontier frontier_broadcast_pipe =
  Broadcast_pipe.Reader.peek frontier_broadcast_pipe
  |> Result.of_option
       ~error:
         (Error.of_string
            "Cannot retrieve transition frontier now. Bootstrapping right now." )

let client_port t =
  let { Node_addrs_and_ports.client_port; _ } =
    t.config.gossip_net_params.addrs_and_ports
  in
  client_port

(* Get the most recently set public keys  *)
let block_production_pubkeys t : Public_key.Compressed.Set.t =
  t.config.block_production_keypairs |> Keypair.And_compressed_pk.Set.to_list
  |> List.map ~f:snd |> Public_key.Compressed.Set.of_list

let coinbase_receiver t = !(t.coinbase_receiver)

let replace_coinbase_receiver t coinbase_receiver =
  [%log' info t.config.logger]
    "Changing the coinbase receiver for produced blocks from $old_receiver to \
     $new_receiver"
    ~metadata:
      [ ( "old_receiver"
        , Consensus.Coinbase_receiver.to_yojson !(t.coinbase_receiver) )
      ; ("new_receiver", Consensus.Coinbase_receiver.to_yojson coinbase_receiver)
      ] ;
  t.coinbase_receiver := coinbase_receiver

let log_snark_worker_warning t =
  if Option.is_some t.config.snark_coordinator_key then
    [%log' warn t.config.logger]
      "The snark coordinator flag is set; running a snark worker will override \
       the snark coordinator key"

let log_snark_coordinator_warning (config : Config.t) snark_worker =
  if Option.is_some config.snark_coordinator_key then
    match snark_worker with
    | `On _ ->
        [%log' warn config.logger]
          "The snark coordinator key will be ignored because the snark worker \
           key is set "
    | _ ->
        ()

module Snark_worker = struct
  let run_process ~logger ~proof_level pids client_port kill_ivar num_threads =
    let env =
      Option.map
        ~f:(fun num -> `Extend [ ("RAYON_NUM_THREADS", string_of_int num) ])
        num_threads
    in
    let%map snark_worker_process =
      let our_binary = Sys.executable_name in
      Process.create_exn () ~prog:our_binary ?env
        ~args:
          ( "internal" :: Snark_worker.Intf.command_name
          :: Snark_worker.arguments ~proof_level
               ~daemon_address:
                 (Host_and_port.create ~host:"127.0.0.1" ~port:client_port)
               ~shutdown_on_disconnect:false )
    in
    Child_processes.Termination.register_process pids snark_worker_process
      Snark_worker ;
    Child_processes.Termination.wait_for_process_log_errors ~logger
      snark_worker_process ~module_:__MODULE__ ~location:__LOC__ ~here:[%here] ;
    let close_stdin () =
      Process.stdin snark_worker_process |> Async.Writer.close
    in
    let remove_pid () =
      let pid = Process.pid snark_worker_process in
      Child_processes.Termination.remove pids pid
    in
    don't_wait_for
      ( match%bind
          Monitor.try_with ~here:[%here] (fun () ->
              Process.wait snark_worker_process )
        with
      | Ok signal_or_error -> (
          let%bind () = close_stdin () in
          remove_pid () ;
          match signal_or_error with
          | Ok () ->
              [%log info] "Snark worker process died" ;
              if Ivar.is_full kill_ivar then
                [%log error] "Ivar.fill bug is here!" ;
              Ivar.fill kill_ivar () ;
              Deferred.unit
          | Error (`Exit_non_zero non_zero_error) ->
              [%log fatal]
                !"Snark worker process died with a nonzero error %i"
                non_zero_error ;
              raise (Snark_worker_error non_zero_error)
          | Error (`Signal signal) ->
              [%log fatal]
                !"Snark worker died with signal %{sexp:Signal.t}. Aborting \
                  daemon"
                signal ;
              raise (Snark_worker_signal_interrupt signal) )
      | Error exn ->
          let%bind () = close_stdin () in
          remove_pid () ;
          [%log info]
            !"Exception when waiting for snark worker process to terminate: \
              $exn"
            ~metadata:[ ("exn", `String (Exn.to_string exn)) ] ;
          Deferred.unit ) ;
    [%log trace]
      !"Created snark worker with pid: %i"
      (Pid.to_int @@ Process.pid snark_worker_process) ;
    (* We want these to be printfs so we don't double encode our logs here *)
    Pipe.iter_without_pushback
      (Async.Reader.pipe (Process.stdout snark_worker_process))
      ~f:(fun s -> printf "%s" s)
    |> don't_wait_for ;
    Pipe.iter_without_pushback
      (Async.Reader.pipe (Process.stderr snark_worker_process))
      ~f:(fun s -> printf "%s" s)
    |> don't_wait_for ;
    snark_worker_process

  let start t =
    O1trace.thread "snark_worker"
    @@ fun () ->
    match t.processes.snark_worker with
    | `On ({ process = process_ivar; kill_ivar; _ }, _) ->
        [%log' debug t.config.logger] !"Starting snark worker process" ;
        log_snark_worker_warning t ;
        let%map snark_worker_process =
          run_process ~logger:t.config.logger
            ~proof_level:t.config.precomputed_values.proof_level t.config.pids
            t.config.gossip_net_params.addrs_and_ports.client_port kill_ivar
            t.config.snark_worker_config.num_threads
        in
        [%log' debug t.config.logger]
          ~metadata:
            [ ( "snark_worker_pid"
              , `Int (Pid.to_int (Process.pid snark_worker_process)) )
            ]
          "Started snark worker process with pid: $snark_worker_pid" ;
        if Ivar.is_full process_ivar then
          [%log' error t.config.logger] "Ivar.fill bug is here!" ;
        Ivar.fill process_ivar snark_worker_process
    | `Off _ ->
        [%log' info t.config.logger]
          !"Attempted to turn on snark worker, but snark worker key is set to \
            none" ;
        Deferred.unit

  let stop ?(should_wait_kill = false) t =
    match t.processes.snark_worker with
    | `On ({ public_key = _; process; kill_ivar }, _) ->
        let%bind process = Ivar.read process in
        [%log' info t.config.logger]
          "Killing snark worker process with pid: $snark_worker_pid"
          ~metadata:
            [ ("snark_worker_pid", `Int (Pid.to_int (Process.pid process))) ] ;
        Signal.send_exn Signal.term (`Pid (Process.pid process)) ;
        if should_wait_kill then Ivar.read kill_ivar else Deferred.unit
    | `Off _ ->
        [%log' warn t.config.logger]
          "Attempted to turn off snark worker, but no snark worker was running" ;
        Deferred.unit

  let get_key { processes = { snark_worker; _ }; _ } =
    match snark_worker with
    | `On ({ public_key; _ }, _) ->
        Some public_key
    | `Off _ ->
        None

  let replace_key t new_key =
    let snark_worker = t.processes.snark_worker in
    let logger = t.config.logger in
    match (snark_worker, new_key) with
    | `Off _, None ->
        [%log info]
          "Snark work is still not happening since keys snark worker keys are \
           still set to None" ;
        Deferred.unit
    | `Off fee, Some new_key ->
        let process = Ivar.create () in
        let kill_ivar = Ivar.create () in
        t.processes.snark_worker <-
          `On ({ public_key = new_key; process; kill_ivar }, fee) ;
        start t
    | `On ({ public_key = old; process; kill_ivar }, fee), Some new_key ->
        [%log debug]
          !"Changing snark worker key from $old to $new"
          ~metadata:
            [ ("old", Public_key.Compressed.to_yojson old)
            ; ("new", Public_key.Compressed.to_yojson new_key)
            ] ;
        t.processes.snark_worker <-
          `On ({ public_key = new_key; process; kill_ivar }, fee) ;
        Deferred.unit
    | `On (_, fee), None ->
        let%map () = stop t in
        t.processes.snark_worker <- `Off fee
end

let replace_snark_worker_key = Snark_worker.replace_key

let snark_worker_key = Snark_worker.get_key

let snark_coordinator_key t = t.config.snark_coordinator_key

let stop_snark_worker = Snark_worker.stop

let best_tip_opt t =
  let open Option.Let_syntax in
  let%map frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  Transition_frontier.best_tip frontier

let transition_frontier t = t.components.transition_frontier

let root_length_opt t =
  let open Option.Let_syntax in
  let%map frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  Transition_frontier.root_length frontier

let best_staged_ledger_opt t =
  let open Option.Let_syntax in
  let%map tip = best_tip_opt t in
  Transition_frontier.Breadcrumb.staged_ledger tip

let best_protocol_state_opt t =
  let open Option.Let_syntax in
  let%map tip = best_tip_opt t in
  Transition_frontier.Breadcrumb.protocol_state tip

let best_ledger_opt t =
  let open Option.Let_syntax in
  let%map staged_ledger = best_staged_ledger_opt t in
  Staged_ledger.ledger staged_ledger

let compose_of_option f =
  Fn.compose
    (Option.value_map ~default:`Bootstrapping ~f:(fun x -> `Active x))
    f

let best_tip = compose_of_option best_tip_opt

let root_length = compose_of_option root_length_opt

let active_or_bootstrapping =
  compose_of_option (fun t ->
      Option.bind
        (Broadcast_pipe.Reader.peek t.components.transition_frontier)
        ~f:(Fn.const (Some ())) )

let get_node_state t =
  let chain_id = t.config.chain_id in
  let addrs_and_ports = t.config.gossip_net_params.addrs_and_ports in
  let peer_id = (Node_addrs_and_ports.to_peer_exn addrs_and_ports).peer_id in
  let ip_address =
    Node_addrs_and_ports.external_ip addrs_and_ports
    |> Core.Unix.Inet_addr.to_string
  in
  let public_key =
    let key_list =
      block_production_pubkeys t |> Public_key.Compressed.Set.to_list
    in
    if List.is_empty key_list then None else Some (List.hd_exn key_list)
  in
  let catchup_job_states =
    match Broadcast_pipe.Reader.peek @@ transition_frontier t with
    | None ->
        None
    | Some tf ->
        let (Full catchup_state) = Transition_frontier.catchup_state tf in
        Some
          (Transition_frontier.Full_catchup_tree.to_node_status_report
             catchup_state )
  in
  let block_height_at_best_tip =
    best_tip t
    |> Participating_state.map ~f:(fun b ->
           Transition_frontier.Breadcrumb.consensus_state b
           |> Consensus.Data.Consensus_state.blockchain_length
           |> Mina_numbers.Length.to_uint32 )
    |> Participating_state.map ~f:Unsigned.UInt32.to_int
    |> Participating_state.active
  in
  let sync_status =
    sync_status t |> Mina_incremental.Status.Observer.value_exn
  in
  let uptime_of_node =
    Time.(
      Span.to_string_hum
      @@ Time.diff (now ())
           (Time_ns.to_time_float_round_nearest_microsecond daemon_start_time))
  in
  let%map hardware_info = Conf_dir.get_hw_info () in
  { Node_error_service.peer_id
  ; ip_address
  ; chain_id
  ; public_key
  ; catchup_job_states
  ; block_height_at_best_tip
  ; sync_status
  ; hardware_info
  ; uptime_of_node
  }

(* This is a hack put in place to deal with nodes getting stuck
   in Offline states, that is, not receiving blocks for an extended period,
   or stuck in Bootstrap for too long

   To address this, we restart the libp2p helper when we become offline. *)
let next_helper_restart = ref None

let offline_shutdown = ref None

exception Offline_shutdown

exception Bootstrap_stuck_shutdown

let create_sync_status_observer ~logger ~genesis_timestamp ~is_seed ~demo_mode
    ~net ~transition_frontier_and_catchup_signal_incr ~online_status_incr
    ~first_connection_incr ~first_message_incr =
  let open Mina_incremental.Status in
  let restart_delay = Time.Span.of_min 5. in
  let offline_shutdown_delay = Time.Span.of_min 25. in
  let genesis_timestamp = Genesis_constants.to_time genesis_timestamp in
  let after_genesis () = Time.(( >= ) (now ())) genesis_timestamp in
  let incremental_status =
    map4 online_status_incr transition_frontier_and_catchup_signal_incr
      first_connection_incr first_message_incr
      ~f:(fun online_status active_status first_connection first_message ->
        (* Always be synced in demo mode, we don't expect peers to connect to us *)
        if demo_mode then `Synced
        else
          match online_status with
          | `Offline ->
              (* nothing to do if offline before genesis *)
              ( if after_genesis () then
                match !next_helper_restart with
                | None ->
                    next_helper_restart :=
                      Some
                        (Async.Clock.Event.run_after restart_delay
                           (fun () ->
                             [%log info]
                               "Offline for too long; restarting libp2p_helper" ;
                             Mina_networking.restart_helper net ;
                             next_helper_restart := None ;
                             if not is_seed then
                               match !offline_shutdown with
                               | None ->
                                   offline_shutdown :=
                                     Some
                                       (Async.Clock.Event.run_after
                                          offline_shutdown_delay
                                          (fun () -> raise Offline_shutdown)
                                          () )
                               | Some _ ->
                                   () )
                           () )
                | Some _ ->
                    () ) ;
              let is_empty = function `Empty -> true | _ -> false in
              if is_empty first_connection then (
                [%str_log info] Connecting ;
                `Connecting )
              else if is_empty first_message then (
                [%str_log info] Listening ;
                `Listening )
              else `Offline
          | `Online -> (
              Option.iter !next_helper_restart ~f:(fun e ->
                  Async.Clock.Event.abort_if_possible e () ) ;
              next_helper_restart := None ;
              Option.iter !offline_shutdown ~f:(fun e ->
                  Async.Clock.Event.abort_if_possible e () ) ;
              offline_shutdown := None ;
              match active_status with
              | None ->
                  let logger = Logger.create () in
                  [%str_log info] Bootstrapping ;
                  `Bootstrap
              | Some (_, catchup_jobs) ->
                  let logger = Logger.create () in
                  if catchup_jobs > 0 then (
                    [%str_log info] Ledger_catchup ;
                    `Catchup )
                  else (
                    [%str_log info] Synced ;
                    `Synced ) ) )
  in
  let observer = observe incremental_status in
  (* monitor Mina status, issue a warning if offline for too long (unless we are a seed node) *)
  ( if not is_seed then
    let offline_timeout_min = 15.0 in
    let offline_timeout_duration = Time.Span.of_min offline_timeout_min in
    let offline_timeout = ref None in
    let offline_warned = ref false in
    let bootstrap_timeout_min = 120.0 in
    let bootstrap_timeout_duration = Time.Span.of_min bootstrap_timeout_min in
    let bootstrap_timeout = ref None in
    let log_offline_warning _tm =
      [%log error]
        "Daemon has not received any gossip messages for %0.0f minutes; check \
         the daemon's external port forwarding, if needed"
        offline_timeout_min ;
      offline_warned := true
    in
    let start_offline_timeout () =
      match !offline_timeout with
      | Some _ ->
          ()
      | None ->
          offline_timeout :=
            Some
              (Timeout.create () offline_timeout_duration ~f:log_offline_warning)
    in
    let stop_offline_timeout () =
      match !offline_timeout with
      | Some timeout ->
          if !offline_warned then (
            [%log info]
              "Daemon had been offline (no gossip messages received), now back \
               online" ;
            offline_warned := false ) ;
          Timeout.cancel () timeout () ;
          offline_timeout := None
      | None ->
          ()
    in
    let log_bootstrap_error_and_restart _tm =
      [%log error] "Daemon has been in bootstrap for %0.0f minutes"
        bootstrap_timeout_min ;
      raise Bootstrap_stuck_shutdown
    in
    let start_bootstrap_timeout () =
      match !bootstrap_timeout with
      | Some _ ->
          ()
      | None ->
          (* don't check bootstrap timeout before genesis *)
          if after_genesis () then
            bootstrap_timeout :=
              Some
                (Timeout.create () bootstrap_timeout_duration
                   ~f:log_bootstrap_error_and_restart )
    in
    let stop_bootstrap_timeout () =
      match !bootstrap_timeout with
      | Some timeout ->
          Timeout.cancel () timeout () ;
          bootstrap_timeout := None
      | None ->
          ()
    in
    let handle_status_change (sync_status : Sync_status.t) =
      ( match sync_status with
      | `Offline ->
          start_offline_timeout ()
      | _ ->
          stop_offline_timeout () ) ;
      match sync_status with
      | `Bootstrap ->
          start_bootstrap_timeout ()
      | _ ->
          stop_bootstrap_timeout ()
    in
    Observer.on_update_exn observer ~f:(function
      | Initialized sync_status ->
          handle_status_change sync_status
      | Changed (_old_sync_status, new_sync_status) ->
          handle_status_change new_sync_status
      | Invalidated ->
          () ) ) ;
  (* recompute Mina status on an interval *)
  let stabilize () = O1trace.sync_thread "stabilize_sync_status" stabilize in
  stabilize () ;
  every (Time.Span.of_sec 15.0) ~stop:(never ()) stabilize ;
  observer

let sync_status t = t.sync_status

let visualize_frontier ~filename =
  compose_of_option
  @@ fun t ->
  let open Option.Let_syntax in
  let%map frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  Transition_frontier.visualize ~filename frontier

let best_staged_ledger = compose_of_option best_staged_ledger_opt

let best_protocol_state = compose_of_option best_protocol_state_opt

let best_ledger = compose_of_option best_ledger_opt

let get_ledger t state_hash_opt =
  let open Deferred.Or_error.Let_syntax in
  let%bind state_hash =
    Deferred.return
    @@ Option.value_map state_hash_opt ~f:Or_error.return
         ~default:
           ( match best_tip t with
           | `Active bc ->
               Or_error.return (Frontier_base.Breadcrumb.state_hash bc)
           | `Bootstrapping ->
               Or_error.error_string
                 "get_ledger: can't get staged ledger hash while bootstrapping"
           )
  in
  let%bind frontier =
    t.components.transition_frontier |> peek_frontier |> Deferred.return
  in
  match Transition_frontier.find frontier state_hash with
  | Some b ->
      let staged_ledger = Transition_frontier.Breadcrumb.staged_ledger b in
      let%map.Deferred accounts =
        Ledger.to_list (Staged_ledger.ledger staged_ledger)
      in
      Ok accounts
  | None ->
      Deferred.return
      @@ Or_error.error_string "state hash not found in transition frontier"

let get_snarked_ledger_full t state_hash_opt =
  let open Deferred.Or_error.Let_syntax in
  let signature_kind = Mina_signature_kind.t_DEPRECATED in
  let%bind state_hash =
    Option.value_map state_hash_opt ~f:Deferred.Or_error.return
      ~default:
        ( match best_tip t with
        | `Active bc ->
            Deferred.Or_error.return (Frontier_base.Breadcrumb.state_hash bc)
        | `Bootstrapping ->
            Deferred.Or_error.error_string
              "get_snarked_ledger: can't get snarked ledger hash while \
               bootstrapping" )
  in
  let%bind frontier =
    t.components.transition_frontier |> peek_frontier |> Deferred.return
  in
  match Transition_frontier.find frontier state_hash with
  | Some b ->
      let root_snarked_ledger =
        Transition_frontier.root_snarked_ledger frontier
      in
      let ledger = Ledger.of_database root_snarked_ledger in
      let path = Transition_frontier.path_map frontier b ~f:Fn.id in
      let%bind () =
        Mina_stdlib.Deferred.Result.List.iter path ~f:(fun b ->
            if Transition_frontier.Breadcrumb.just_emitted_a_proof b then
              (*Validate transactions against the protocol state associated with the transaction*)
              let get_protocol_state state_hash =
                match
                  Transition_frontier.find_protocol_state frontier state_hash
                with
                | Some s ->
                    Ok s
                | None ->
                    Or_error.errorf "Failed to find protocol state for hash %s"
                      (State_hash.to_base58_check state_hash)
              in
              let apply_first_pass =
                Ledger.apply_transaction_first_pass ~signature_kind
                  ~constraint_constants:
                    t.config.precomputed_values.constraint_constants
              in
              let apply_second_pass = Ledger.apply_transaction_second_pass in
              let apply_first_pass_sparse_ledger ~global_slot ~txn_state_view
                  sparse_ledger txn =
                let open Or_error.Let_syntax in
                let%map _ledger, partial_txn =
                  Mina_ledger.Sparse_ledger.apply_transaction_first_pass
                    ~constraint_constants:
                      t.config.precomputed_values.constraint_constants
                    ~global_slot ~txn_state_view sparse_ledger txn
                in
                partial_txn
              in
              Staged_ledger.Scan_state.get_snarked_ledger_async ~ledger
                ~get_protocol_state ~apply_first_pass ~apply_second_pass
                ~apply_first_pass_sparse_ledger
                (Staged_ledger.scan_state
                   (Transition_frontier.Breadcrumb.staged_ledger b) )
              |> Deferred.Result.map_error ~f:(fun e ->
                     Error.createf
                       "Failed to apply proof transactions for state_hash:%s : \
                        %s"
                       (State_hash.to_base58_check
                          (Transition_frontier.Breadcrumb.state_hash b) )
                       (Error.to_string_hum e) )
            else return () )
      in
      let snarked_ledger_hash =
        Transition_frontier.Breadcrumb.block b
        |> Mina_block.header |> Header.protocol_state
        |> Mina_state.Protocol_state.blockchain_state
        |> Mina_state.Blockchain_state.snarked_ledger_hash
      in
      let merkle_root = Ledger.merkle_root ledger in
      if Frozen_ledger_hash.equal snarked_ledger_hash merkle_root then
        return ledger
      else
        Deferred.Or_error.errorf
          "Expected snarked ledger hash %s but got %s for state hash %s"
          (Frozen_ledger_hash.to_base58_check snarked_ledger_hash)
          (Frozen_ledger_hash.to_base58_check merkle_root)
          (State_hash.to_base58_check state_hash)
  | None ->
      Deferred.Or_error.error_string
        "get_snarked_ledger: state hash not found in transition frontier"

let get_snarked_ledger t state_hash_opt =
  let open Deferred.Or_error.Let_syntax in
  let%bind ledger = get_snarked_ledger_full t state_hash_opt in
  let%map.Deferred res = Ledger.to_list ledger in
  ignore @@ Ledger.unregister_mask_exn ~loc:__LOC__ ledger ;
  Ok res

let get_account t aid =
  let open Participating_state.Let_syntax in
  let%map ledger = best_ledger t in
  let open Option.Let_syntax in
  let%bind loc = Ledger.location_of_account ledger aid in
  Ledger.get ledger loc

let get_inferred_nonce_from_transaction_pool_and_ledger t
    (account_id : Account_id.t) =
  let transaction_pool = t.components.transaction_pool in
  let resource_pool =
    Network_pool.Transaction_pool.resource_pool transaction_pool
  in
  let pooled_transactions =
    Network_pool.Transaction_pool.Resource_pool.all_from_account resource_pool
      account_id
  in
  let txn_pool_nonce =
    List.last pooled_transactions
    |> Option.map
         ~f:
           (Fn.compose User_command.expected_target_nonce
              Transaction_hash.User_command_with_valid_signature.command )
  in
  match txn_pool_nonce with
  | Some nonce ->
      Participating_state.Option.return nonce
  | None ->
      let open Participating_state.Option.Let_syntax in
      let%map account = get_account t account_id in
      account.Account.nonce

let snark_job_state t = t.snark_job_state

let add_block_subscriber t public_key =
  Mina_subscriptions.add_block_subscriber t.subscriptions public_key

let add_payment_subscriber t public_key =
  Mina_subscriptions.add_payment_subscriber t.subscriptions public_key

let transaction_pool t = t.components.transaction_pool

let snark_pool t = t.components.snark_pool

let peers t = Mina_networking.peers t.components.net

let initial_peers t = Mina_networking.initial_peers t.components.net

let snark_work_fee t =
  match t.processes.snark_worker with `On (_, fee) -> fee | `Off fee -> fee

let set_snark_work_fee t new_fee =
  t.processes.snark_worker <-
    ( match t.processes.snark_worker with
    | `On (config, _) ->
        `On (config, new_fee)
    | `Off _ ->
        `Off new_fee )

let top_level_logger t = t.config.logger

let most_recent_valid_transition t = t.components.most_recent_valid_block

let block_produced_bvar t = t.components.block_produced_bvar

let staged_ledger_ledger_proof t =
  let open Option.Let_syntax in
  let%bind sl = best_staged_ledger_opt t in
  Staged_ledger.current_ledger_proof sl

let validated_transitions t = t.pipes.validated_transitions_reader

let initialization_finish_signal t = t.initialization_finish_signal

let dump_tf t =
  peek_frontier t.components.transition_frontier
  |> Or_error.map ~f:Transition_frontier.visualize_to_string

(** The [best_path coda] is the list of state hashes from the root to the best_tip in the transition frontier. It includes the root hash and the hash *)
let best_path t =
  let open Option.Let_syntax in
  let%map tf = Broadcast_pipe.Reader.peek t.components.transition_frontier in
  let bt = Transition_frontier.best_tip tf in
  List.cons
    Transition_frontier.(root tf |> Breadcrumb.state_hash)
    (Transition_frontier.hash_path tf bt)

let best_chain ?max_length t =
  let open Option.Let_syntax in
  let%map frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  let best_tip_path = Transition_frontier.best_tip_path ?max_length frontier in
  match max_length with
  | Some max_length
    when Mina_stdlib.List.Length.Compare.(best_tip_path >= max_length) ->
      (* The [best_tip_path] has already been truncated to the correct length,
         we skip adding the root to stay below the maximum.
      *)
      best_tip_path
  | _ ->
      Transition_frontier.root frontier :: best_tip_path

let request_work t =
  let (module Work_selection_method) = t.config.work_selection_method in
  let fee = snark_work_fee t in
  let instances_opt =
    Work_selection_method.work ~logger:t.config.logger ~fee
      ~snark_pool:(snark_pool t) (snark_job_state t)
  in
  Option.map instances_opt ~f:(fun instances ->
      { Snark_work_lib.Work.Spec.instances; fee } )

let work_selection_method t = t.config.work_selection_method

let add_work t (work : Snark_work_lib.Selector.Result.Stable.Latest.t) =
  let update_metrics () =
    let snark_pool = snark_pool t in
    let fee_opt =
      Option.map (snark_worker_key t) ~f:(fun _ -> snark_work_fee t)
    in
    let pending_work =
      Work_selector.pending_work_statements ~snark_pool ~fee_opt
        t.snark_job_state
      |> List.length
    in
    Mina_metrics.(
      Gauge.set Snark_work.pending_snark_work (Int.to_float pending_work))
  in
  let spec =
    One_or_two.map work.spec.instances
      ~f:Snark_work_lib.Work.Single.Spec.statement
  in
  let cb _ =
    (* remove it from seen jobs after attempting to adding it to the pool to avoid this work being reassigned
     * If the diff is accepted then remove it from the seen jobs.
     * If not then the work should have already been in the pool with a lower fee or the statement isn't referenced anymore or any other error. In any case remove it from the seen jobs so that it can be picked up if needed *)
    Work_selector.remove t.snark_job_state spec
  in
  ignore (Or_error.try_with (fun () -> update_metrics ()) : unit Or_error.t) ;
  Network_pool.Snark_pool.(
    Local_sink.push t.pipes.snark_local_sink
      (Resource_pool.Diff.of_result work, cb))
  |> Deferred.don't_wait_for

let add_work_graphql t diff =
  let results_ivar = Ivar.create () in
  Network_pool.Snark_pool.Local_sink.push t.pipes.snark_local_sink
    (diff, Ivar.fill results_ivar)
  |> Deferred.don't_wait_for ;
  Ivar.read results_ivar

let get_current_nonce t aid =
  match
    Participating_state.active
      (get_inferred_nonce_from_transaction_pool_and_ledger t aid)
    |> Option.join
  with
  | None ->
      (* IMPORTANT! Do not change the content of this error without
       * updating Rosetta's construction API to handle the changes *)
      Error
        "Couldn't infer nonce for transaction from specified `sender` since \
         `sender` is not in the ledger or sent a transaction in transaction \
         pool."
  | Some nonce ->
      let ledger_nonce =
        Participating_state.active (get_account t aid)
        |> Option.join
        |> Option.map ~f:(fun { Account.nonce; _ } -> nonce)
        |> Option.value ~default:nonce
      in
      Ok (`Min ledger_nonce, nonce)

let add_transactions t (uc_inputs : User_command_input.t list) =
  let result_ivar = Ivar.create () in
  let cmd_inputs = Signed_command_inputs uc_inputs in
  Strict_pipe.Writer.write t.pipes.user_command_input_writer
    (cmd_inputs, Ivar.fill result_ivar, get_current_nonce t, get_account t)
  |> Deferred.don't_wait_for ;
  Ivar.read result_ivar

let add_full_transactions t user_commands =
  let add_all_txns () =
    let result_ivar = Ivar.create () in
    Network_pool.Transaction_pool.Local_sink.push t.pipes.tx_local_sink
      (user_commands, Ivar.fill result_ivar)
    |> Deferred.don't_wait_for ;
    Ivar.read result_ivar
  in
  let well_formed_errors =
    List.find_map user_commands ~f:(fun cmd ->
        match
          User_command.check_well_formedness
            ~genesis_constants:t.config.precomputed_values.genesis_constants cmd
        with
        | Ok () ->
            None
        | Error errs ->
            Some errs )
  in
  match well_formed_errors with
  | None ->
      add_all_txns ()
  | Some errs ->
      let error =
        Error.of_string
          ( List.map errs ~f:User_command.Well_formedness_error.to_string
          |> String.concat ~sep:"," )
      in
      Deferred.Result.fail error

let add_zkapp_transactions t
    (zkapp_commands : Zkapp_command.Stable.Latest.t list) =
  let add_all_txns () =
    let result_ivar = Ivar.create () in
    let cmd_inputs = Zkapp_command_command_inputs zkapp_commands in
    Strict_pipe.Writer.write t.pipes.user_command_input_writer
      (cmd_inputs, Ivar.fill result_ivar, get_current_nonce t, get_account t)
    |> Deferred.don't_wait_for ;
    Ivar.read result_ivar
  in
  let well_formed_errors =
    List.find_map zkapp_commands ~f:(fun cmd ->
        match
          User_command.check_well_formedness
            ~genesis_constants:t.config.precomputed_values.genesis_constants
            (Zkapp_command cmd)
        with
        | Ok () ->
            None
        | Error errs ->
            Some errs )
  in
  match well_formed_errors with
  | None ->
      add_all_txns ()
  | Some errs ->
      let error =
        Error.of_string
          ( List.map errs ~f:User_command.Well_formedness_error.to_string
          |> String.concat ~sep:"," )
      in
      Deferred.Result.fail error

let next_producer_timing t = t.next_producer_timing

let staking_ledger t =
  let open Option.Let_syntax in
  let consensus_constants = t.config.precomputed_values.consensus_constants in
  let%map transition_frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  let consensus_state =
    Transition_frontier.Breadcrumb.consensus_state
      (Transition_frontier.best_tip transition_frontier)
  in
  let local_state = t.config.consensus_local_state in
  Consensus.Hooks.get_epoch_ledger ~constants:consensus_constants
    ~consensus_state ~local_state

let next_epoch_ledger t =
  let open Option.Let_syntax in
  let%map frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  let root = Transition_frontier.root frontier in
  let root_epoch =
    Transition_frontier.Breadcrumb.consensus_state root
    |> Consensus.Data.Consensus_state.epoch_count
  in
  let best_tip = Transition_frontier.best_tip frontier in
  let best_tip_epoch =
    Transition_frontier.Breadcrumb.consensus_state best_tip
    |> Consensus.Data.Consensus_state.epoch_count
  in
  if
    Mina_numbers.Length.(
      equal root_epoch best_tip_epoch || equal best_tip_epoch zero)
  then
    (*root is in the same epoch as the best tip and so the next epoch ledger in the local state will be updated by Proof_of_stake.frontier_root_transition. Next epoch ledger in genesis epoch is the genesis ledger*)
    `Finalized
      (Consensus.Data.Local_state.next_epoch_ledger
         t.config.consensus_local_state )
  else
    (*No blocks in the new epoch is finalized yet, return nothing*)
    `Notfinalized

let find_delegators table pk =
  Option.value_map
    (Public_key.Compressed.Table.find table pk)
    ~default:[] ~f:Mina_base.Account.Index.Table.data

let current_epoch_delegators t ~pk =
  let open Option.Let_syntax in
  let%map _transition_frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  let current_epoch_delegatee_table =
    Consensus.Data.Local_state.current_epoch_delegatee_table
      ~local_state:t.config.consensus_local_state
  in
  find_delegators current_epoch_delegatee_table pk

let last_epoch_delegators t ~pk =
  let open Option.Let_syntax in
  let%bind _transition_frontier =
    Broadcast_pipe.Reader.peek t.components.transition_frontier
  in
  let%map last_epoch_delegatee_table =
    Consensus.Data.Local_state.last_epoch_delegatee_table
      ~local_state:t.config.consensus_local_state
  in
  find_delegators last_epoch_delegatee_table pk

let perform_compaction compaction_interval t =
  match compaction_interval with
  | None ->
      ()
  | Some compaction_interval_compiled ->
      let slot_duration_ms =
        let leeway = 1000 in
        t.config.precomputed_values.constraint_constants
          .block_window_duration_ms + leeway
      in
      let expected_time_for_compaction =
        match Sys.getenv "MINA_COMPACTION_MS" with
        | Some ms ->
            Float.of_string ms
        | None ->
            6000.
      in
      let span ?(incr = 0.) ms = Float.(of_int ms +. incr) |> Time.Span.of_ms in
      let interval_configured =
        match Sys.getenv "MINA_COMPACTION_INTERVAL_MS" with
        | Some ms ->
            Time.Span.of_ms (Float.of_string ms)
        | None ->
            compaction_interval_compiled
      in
      if Time.Span.(interval_configured <= of_ms expected_time_for_compaction)
      then (
        [%log' fatal t.config.logger]
          "Time between compactions %f should be greater than the expected \
           time for compaction %f"
          (Time.Span.to_ms interval_configured)
          expected_time_for_compaction ;
        failwith
          (sprintf
             "Time between compactions %f should be greater than the expected \
              time for compaction %f"
             (Time.Span.to_ms interval_configured)
             expected_time_for_compaction ) ) ;
      let call_compact () =
        let start = Time.now () in
        Gc.compact () ;
        let span = Time.diff (Time.now ()) start in
        [%log' debug t.config.logger]
          ~metadata:[ ("time", `Float (Time.Span.to_ms span)) ]
          "Gc.compact took $time ms"
      in
      let rec perform interval =
        upon (after interval) (fun () ->
            match !(t.block_production_status) with
            | `Free ->
                call_compact () ;
                perform interval_configured
            | `Producing ->
                perform (span slot_duration_ms)
            | `Producing_in_ms ms ->
                if Float.(ms < expected_time_for_compaction) then
                  (*too close to block production; perform compaction after block production*)
                  perform (span slot_duration_ms ~incr:ms)
                else (
                  call_compact () ;
                  perform interval_configured ) )
      in
      perform interval_configured

let check_and_stop_daemon t ~wait =
  let uptime_mins =
    Time_ns.(diff (now ()) daemon_start_time |> Span.to_min |> Int.of_float)
  in
  let max_catchup_time = Time.Span.of_hr 1. in
  if uptime_mins <= wait then
    `Check_in
      (Block_time.Span.to_time_span
         t.config.precomputed_values.consensus_constants.slot_duration_ms )
  else
    match t.next_producer_timing with
    | None ->
        `Now
    | Some timing -> (
        match timing.timing with
        | Daemon_rpcs.Types.Status.Next_producer_timing.Check_again tm
        | Produce { time = tm; _ }
        | Produce_now { time = tm; _ } ->
            let tm = Block_time.to_time_exn tm in
            (*Assuming it takes at most 1hr to bootstrap and catchup*)
            let next_block =
              Time.add tm
                (Block_time.Span.to_time_span
                   t.config.precomputed_values.consensus_constants
                     .slot_duration_ms )
            in
            let wait_for = Time.(diff next_block (now ())) in
            if Time.Span.(wait_for > max_catchup_time) then `Now
            else `Check_in wait_for
        | Evaluating_vrf _last_checked_slot ->
            let vrf_poll_interval =
              (config t).compile_config.vrf_poll_interval
            in
            `Check_in (Core.Time.Span.scale vrf_poll_interval 2.0) )

let stop_long_running_daemon t =
  let wait_mins = (t.config.stop_time * 60) + (Random.int 10 * 60) in
  [%log' info t.config.logger]
    "Stopping daemon after $wait mins and when there are no blocks to be \
     produced"
    ~metadata:[ ("wait", `Int wait_mins) ] ;
  let stop_daemon () =
    let uptime_mins =
      Time_ns.(diff (now ()) daemon_start_time |> Span.to_min |> Int.of_float)
    in
    [%log' info t.config.logger]
      "Deamon has been running for $uptime mins. Stopping now..."
      ~metadata:[ ("uptime", `Int uptime_mins) ] ;
    Scheduler.yield ()
    >>= (fun () -> return (Async.shutdown 1))
    |> don't_wait_for
  in
  let rec go interval =
    upon (after interval) (fun () ->
        match check_and_stop_daemon t ~wait:wait_mins with
        | `Now ->
            stop_daemon ()
        | `Check_in tm ->
            go tm )
  in
  go (Time.Span.of_ms (wait_mins * 60 * 1000 |> Float.of_int))

let offline_time
    { Genesis_constants.Constraint_constants.block_window_duration_ms; _ } =
  (* This is a bit of a hack, see #3232. *)
  let inactivity_ms = block_window_duration_ms * 8 in
  Block_time.Span.of_ms @@ Int64.of_int inactivity_ms

let setup_timer ~constraint_constants time_controller sync_state_broadcaster =
  Block_time.Timeout.create time_controller (offline_time constraint_constants)
    ~f:(fun _ ->
      Broadcast_pipe.Writer.write sync_state_broadcaster `Offline
      |> don't_wait_for )

let online_broadcaster ~constraint_constants time_controller =
  let online_reader, online_writer = Broadcast_pipe.create `Offline in
  let init =
    Block_time.Timeout.create time_controller
      (Block_time.Span.of_ms Int64.zero)
      ~f:ignore
  in
  let current_timer = ref init in
  let notify_online () =
    let%map () = Broadcast_pipe.Writer.write online_writer `Online in
    Block_time.Timeout.cancel time_controller !current_timer () ;
    current_timer :=
      setup_timer ~constraint_constants time_controller online_writer
  in
  (online_reader, notify_online)

module type CONTEXT = sig
  val logger : Logger.t

  val time_controller : Block_time.Controller.t

  val trust_system : Trust_system.t

  val consensus_local_state : Consensus.Data.Local_state.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val commit_id : string

  val vrf_poll_interval : Time.Span.t

  val zkapp_cmd_limit : int option ref

  val compaction_interval : Time.Span.t option

  val ledger_sync_config : Syncable_ledger.daemon_config

  val proof_cache_db : Proof_cache_tag.cache_db
end

let context ~commit_id ~proof_cache_db (config : Config.t) : (module CONTEXT) =
  ( module struct
    let logger = config.logger

    let time_controller = config.time_controller

    let trust_system = config.trust_system

    let consensus_local_state = config.consensus_local_state

    let precomputed_values = config.precomputed_values

    let consensus_constants = precomputed_values.consensus_constants

    let constraint_constants = precomputed_values.constraint_constants

    let commit_id = commit_id

    let vrf_poll_interval = config.compile_config.vrf_poll_interval

    let zkapp_cmd_limit = config.zkapp_cmd_limit

    let compaction_interval = config.compile_config.compaction_interval

    let ledger_sync_config =
      let open Option.Let_syntax in
      let max_subtree_depth =
        let%bind daemon = precomputed_values.runtime_config.daemon in
        daemon.sync_ledger_max_subtree_depth
      in
      let default_subtree_depth =
        let%bind daemon = precomputed_values.runtime_config.daemon in
        daemon.sync_ledger_default_subtree_depth
      in
      Syncable_ledger.create_config ~compile_config:config.compile_config
        ~max_subtree_depth ~default_subtree_depth ()

    let proof_cache_db = proof_cache_db
  end )

let start t =
  let commit_id_short = String.sub ~pos:0 ~len:8 t.commit_id in
  let set_next_producer_timing timing consensus_state =
    let block_production_status, next_producer_timing =
      let generated_from_consensus_at :
          Daemon_rpcs.Types.Status.Next_producer_timing.slot =
        { slot = Consensus.Data.Consensus_state.curr_global_slot consensus_state
        ; global_slot_since_genesis =
            Consensus.Data.Consensus_state.global_slot_since_genesis
              consensus_state
        }
      in
      let info time (data : Consensus.Data.Block_data.t) :
          Daemon_rpcs.Types.Status.Next_producer_timing.producing_time =
        let for_slot : Daemon_rpcs.Types.Status.Next_producer_timing.slot =
          { slot = Consensus.Data.Block_data.global_slot data
          ; global_slot_since_genesis =
              Consensus.Data.Block_data.global_slot_since_genesis data
          }
        in
        { time; for_slot }
      in
      let status, timing =
        match timing with
        | `Check_again block_time ->
            ( `Free
            , Daemon_rpcs.Types.Status.Next_producer_timing.Check_again
                block_time )
        | `Evaluating_vrf last_checked_slot ->
            (* Vrf evaluation is still going on, so treating it as if a block is being produced*)
            (`Producing, Evaluating_vrf last_checked_slot)
        | `Produce_now (block_data, _) ->
            let info :
                Daemon_rpcs.Types.Status.Next_producer_timing.producing_time =
              let time =
                Consensus.Data.Consensus_time.of_global_slot
                  ~constants:t.config.precomputed_values.consensus_constants
                  (Consensus.Data.Block_data.global_slot block_data)
                |> Consensus.Data.Consensus_time.to_time
                     ~constants:t.config.precomputed_values.consensus_constants
              in
              info time block_data
            in
            (`Producing, Produce_now info)
        | `Produce (time, block_data, _) ->
            ( `Producing_in_ms (Int64.to_float time)
            , Produce
                (info
                   ( time |> Block_time.Span.of_ms
                   |> Block_time.of_span_since_epoch )
                   block_data ) )
      in
      ( status
      , { Daemon_rpcs.Types.Status.Next_producer_timing.timing
        ; generated_from_consensus_at
        } )
    in
    t.block_production_status := block_production_status ;
    t.next_producer_timing <- Some next_producer_timing
  in
  ( if
    not
      (Keypair.And_compressed_pk.Set.is_empty t.config.block_production_keypairs)
  then
    let module Context =
    ( val context ~proof_cache_db:t.proof_cache_db ~commit_id:t.commit_id
            t.config )
    in
    Block_producer.run
      ~context:(module Context)
      ~vrf_evaluator:t.processes.vrf_evaluator ~verifier:t.processes.verifier
      ~set_next_producer_timing ~prover:t.processes.prover
      ~trust_system:t.config.trust_system
      ~transaction_resource_pool:
        (Network_pool.Transaction_pool.resource_pool
           t.components.transaction_pool )
      ~get_completed_work:
        (Network_pool.Snark_pool.get_completed_work t.components.snark_pool)
      ~time_controller:t.config.time_controller
      ~coinbase_receiver:t.coinbase_receiver
      ~consensus_local_state:t.config.consensus_local_state
      ~frontier_reader:t.components.transition_frontier
      ~transition_writer:t.pipes.producer_transition_writer
      ~log_block_creation:t.config.log_block_creation
      ~block_reward_threshold:t.config.block_reward_threshold
      ~block_produced_bvar:t.components.block_produced_bvar
      ~vrf_evaluation_state:t.vrf_evaluation_state ~net:t.components.net
      ~zkapp_cmd_limit_hardcap:
        t.config.precomputed_values.genesis_constants.zkapp_cmd_limit_hardcap ) ;
  perform_compaction t.config.compile_config.compaction_interval t ;
  let () =
    match t.config.node_status_url with
    | Some node_status_url ->
        if t.config.simplified_node_stats then
          let block_producer_public_key_base58 =
            Option.map ~f:(fun (_, pk) ->
                Public_key.Compressed.to_base58_check pk )
            @@ Keypair.And_compressed_pk.Set.choose
                 t.config.block_production_keypairs
          in
          Node_status_service.start_simplified ~commit_id:t.commit_id
            ~logger:t.config.logger ~node_status_url ~network:t.components.net
            ~chain_id:t.config.chain_id
            ~addrs_and_ports:t.config.gossip_net_params.addrs_and_ports
            ~slot_duration:
              (Block_time.Span.to_time_span
                 t.config.precomputed_values.consensus_constants
                   .slot_duration_ms )
            ~block_producer_public_key_base58
        else
          Node_status_service.start ~commit_id:t.commit_id
            ~logger:t.config.logger ~node_status_url ~network:t.components.net
            ~transition_frontier:t.components.transition_frontier
            ~sync_status:t.sync_status ~chain_id:t.config.chain_id
            ~addrs_and_ports:t.config.gossip_net_params.addrs_and_ports
            ~start_time:t.config.start_time
            ~slot_duration:
              (Block_time.Span.to_time_span
                 t.config.precomputed_values.consensus_constants
                   .slot_duration_ms )
    | None ->
        ()
  in
  let built_with_commit_sha =
    if t.config.uptime_send_node_commit then Some commit_id_short else None
  in
  Uptime_service.start ~logger:t.config.logger ~uptime_url:t.config.uptime_url
    ~snark_worker_opt:t.processes.uptime_snark_worker_opt
    ~transition_frontier:t.components.transition_frontier
    ~constraint_constants:t.config.precomputed_values.constraint_constants
    ~protocol_constants:t.config.precomputed_values.genesis_constants.protocol
    ~time_controller:t.config.time_controller
    ~block_produced_bvar:t.components.block_produced_bvar
    ~uptime_submitter_keypair:t.config.uptime_submitter_keypair
    ~graphql_control_port:t.config.graphql_control_port ~built_with_commit_sha
    ~get_next_producer_timing:(fun () -> t.next_producer_timing)
    ~get_snark_work_fee:(fun () -> snark_work_fee t)
    ~get_peer:(fun () -> t.config.gossip_net_params.addrs_and_ports.peer) ;
  stop_long_running_daemon t ;
  Snark_worker.start t

let start_with_precomputed_blocks t blocks =
  let module Context =
  (val context ~proof_cache_db:t.proof_cache_db ~commit_id:t.commit_id t.config)
  in
  let%bind () =
    Block_producer.run_precomputed
      ~context:(module Context)
      ~verifier:t.processes.verifier ~trust_system:t.config.trust_system
      ~time_controller:t.config.time_controller
      ~frontier_reader:t.components.transition_frontier
      ~transition_writer:t.pipes.producer_transition_writer
      ~precomputed_blocks:blocks
  in
  start t

let send_resource_pool_diff_or_wait ~rl ~diff_score ~max_per_15_seconds diff =
  (* HACK: Pretend we're a remote peer so that we can rate limit
                 ourselves.
  *)
  let us : Network_peer.Peer.t =
    { host = Unix.Inet_addr.of_string "127.0.0.1"
    ; libp2p_port = 0
    ; peer_id = ""
    }
  in
  let score = diff_score diff in
  let rec able_to_send_or_wait () =
    match
      Network_pool.Rate_limiter.add rl (Remote us) ~now:(Time.now ()) ~score
    with
    | `Within_capacity ->
        Deferred.return ()
    | `Capacity_exceeded ->
        if score > max_per_15_seconds then (
          (* This will never pass the rate limiting; pass it on
                             to progress in the queue. *)
          ignore
            ( Network_pool.Rate_limiter.add rl (Remote us) ~now:(Time.now ())
                ~score:0
              : [ `Within_capacity | `Capacity_exceeded ] ) ;
          Deferred.return () )
        else
          let%bind () =
            after
              Time.(
                diff (now ())
                  (Network_pool.Rate_limiter.next_expires rl (Remote us)))
          in
          able_to_send_or_wait ()
  in
  able_to_send_or_wait ()

module type Itn_settable = sig
  type t

  val set_itn_logger_data : t -> daemon_port:int -> unit Deferred.Or_error.t
end

let start_filtered_log ~commit_id
    in_memory_reverse_structured_log_messages_for_integration_test
    (structured_log_ids : string list) =
  let handle str =
    let idx, old_messages, started =
      !in_memory_reverse_structured_log_messages_for_integration_test
    in
    in_memory_reverse_structured_log_messages_for_integration_test :=
      (idx + 1, str :: old_messages, started)
  in
  let _, _, started =
    !in_memory_reverse_structured_log_messages_for_integration_test
  in
  if started then Or_error.error_string "Already initialized"
  else (
    in_memory_reverse_structured_log_messages_for_integration_test :=
      (0, [], true) ;
    let event_set =
      Structured_log_events.Set.of_list
      @@ List.map ~f:Structured_log_events.id_of_string structured_log_ids
    in
    Logger.Consumer_registry.register ~id:Logger.Logger_id.mina ~commit_id
      ~processor:(Logger.Processor.raw_structured_log_events event_set)
      ~transport:(Logger.Transport.raw handle)
      () ;
    Ok () )

let fetch_completed_snarks (module Context : CONTEXT) snark_pool network
    received_block get_current_frontier =
  let open Context in
  let open Network_peer in
  let%bind all_peers = Mina_networking.peers network in
  let peer_limit = 5 in
  let limited_peers = List.take all_peers peer_limit in
  let check_every = Time.Span.of_ms 20. in
  let log_every = Time.Span.of_sec 10. in
  let log_rate = Time.Span.( // ) log_every check_every |> Float.to_int in

  (* Keep reading from the transition frontier until it has caught up to the most valid block from the network.
     * This is to ensure that the snarks are verified and added to the pool in the correct order
  *)
  let rec wait_for_new_top_block received_block iteration_count =
    let frontier = get_current_frontier () in
    match frontier with
    | None ->
        let iteration_count =
          if iteration_count >= log_rate then (
            [%log error]
              "Transition frontier is not available after sync something has \
               gone terribly wrong" ;
            0 )
          else iteration_count + 1
        in
        let%bind () = after check_every in
        wait_for_new_top_block received_block iteration_count
    | Some frontier ->
        let tip = Transition_frontier.best_tip frontier in
        let top_block =
          Transition_frontier.Breadcrumb.validated_transition tip
          |> Mina_block.Validated.header |> Mina_block.Header.blockchain_length
        in
        let delta =
          Unsigned.UInt32.(Infix.(received_block - top_block) |> to_int)
        in
        (* if delta is less than or equal to zero the transition frontier has caught up with the network *)
        if delta <= 0 then Deferred.unit
        else
          let iteration_count =
            if iteration_count >= log_rate then (
              [%log debug]
                ~metadata:
                  [ ( "old_top_block"
                    , `Int (received_block |> Unsigned.UInt32.to_int) )
                  ; ("new_top_block", `Int (top_block |> Unsigned.UInt32.to_int))
                  ]
                "WAITING  old top block: $old_top_block, new top block: \
                 $new_top_block" ;
              0 )
            else iteration_count + 1
          in
          let%bind () = after check_every in
          wait_for_new_top_block received_block iteration_count
  in
  let%bind () = wait_for_new_top_block received_block log_rate in

  Deferred.List.iter
    ~f:(fun peer ->
      [%log debug] "PEER IS: Fetching completed snarks from peer: $peer"
        ~metadata:[ ("peer", Network_peer.Peer.to_yojson peer) ] ;
      let completed_works =
        Mina_networking.get_completed_checked_snarks network peer
      in
      let%bind completed_works = completed_works in
      let completed_works =
        match completed_works with
        | Error e ->
            [%log debug]
              ~metadata:
                [ ("peer", Network_peer.Peer.to_yojson peer)
                ; ("error", Error_json.error_to_yojson e)
                ]
              "Failed to fetch completed snarks from peer: $error" ;
            []
        | Ok completed_works ->
            completed_works
      in

      [%log debug]
        ~metadata:
          [ ("peer", Network_peer.Peer.to_yojson peer)
          ; ("completed_works", `Int (List.length completed_works))
          ]
        "Fetched $completed_works completed snarks from peer: $peer" ;

      (* verify the snarks and add them to the pool *)
      let%bind () =
        Deferred.List.iter completed_works ~f:(fun work ->
            (* proofs should be verified in apply and broadcast *)
            let statement =
              Transaction_snark_work.Stable.Latest.statement work
            in
            let snark =
              Network_pool.Priced_proof.
                { proof = work.proofs
                ; fee = { fee = work.fee; prover = work.prover }
                }
            in
            let msg =
              let diff =
                Network_pool.Snark_pool.Diff_versioned.Stable.Latest
                .Add_solved_work
                  (statement, snark)
              in
              Envelope.Incoming.wrap_peer ~data:diff ~sender:peer
            in
            (* verify the snarks to be added *)
            let resource_pool =
              Network_pool.Snark_pool.resource_pool snark_pool
            in
            let%bind err =
              Network_pool.Snark_pool.Resource_pool.verify_and_act resource_pool
                ~work:(statement, snark) ~sender:msg.sender
            in
            match err with
            | Ok () ->
                [%log info]
                  ~metadata:
                    [ ("peer", Network_peer.Peer.to_yojson peer)
                    ; ( "work_ids"
                      , Transaction_snark_work.Statement.compact_json statement
                      )
                    ]
                  "Successfully verified snark work from peer: $peer" ;

                (* does an empty check for the snark, then an unsafe apply, and finally adds it to the pool *)
                Deferred.return
                  Network_pool.Snark_pool.(
                    apply_no_broadcast snark_pool
                      (Envelope.Incoming.map
                         ~f:
                           (Resource_pool.Diff.Cached.write_all_proofs_to_disk
                              ~proof_cache_db )
                         msg ))
            | Error e ->
                [%log info]
                  ~metadata:
                    [ ("peer", Network_peer.Peer.to_yojson peer)
                    ; ( "work_ids"
                      , Transaction_snark_work.Statement.compact_json statement
                      )
                    ; ( "error"
                      , Network_pool.Intf.Verification_error.to_error e
                        |> Error_json.error_to_yojson )
                    ]
                  "Failed to verify snark work from peer: $peer" ;
                Deferred.unit )
      in
      Deferred.unit )
    limited_peers

let raise_on_initialization_error (`Initialization_error e) =
  Error.raise @@ Error.tag ~tag:"proof cache initialization error" e

let initialize_proof_cache_db (config : Config.t) =
  Proof_cache_tag.create_db ~logger:config.logger
    (config.conf_dir ^/ "proof_cache")
  >>| function Error e -> raise_on_initialization_error e | Ok db -> db

let initialize_zkapp_vk_cache_db (config : Config.t) =
  Zkapp_vk_cache_tag.create_db ~logger:config.logger
    (config.conf_dir ^/ "zkapp_vk_cache")
  >>| function Error e -> raise_on_initialization_error e | Ok db -> db

let create ~commit_id ?wallets (config : Config.t) =
  let commit_id_short = String.sub ~pos:0 ~len:8 commit_id in
  let constraint_constants = config.precomputed_values.constraint_constants in
  let consensus_constants = config.precomputed_values.consensus_constants in
  let block_window_duration = config.compile_config.block_window_duration in
  let monitor = Option.value ~default:(Monitor.create ()) config.monitor in
  Async.Scheduler.within' ~monitor (fun () ->
      let set_itn_data (type t) (module M : Itn_settable with type t = t) (t : t)
          =
        if config.itn_features then
          let ({ client_port; _ } : Node_addrs_and_ports.t) =
            config.gossip_net_params.addrs_and_ports
          in
          match%map M.set_itn_logger_data t ~daemon_port:client_port with
          | Ok () ->
              ()
          | Error err ->
              [%log' warn config.logger]
                "Error when setting ITN logger data: %s"
                (Error.to_string_hum err)
        else Deferred.unit
      in
      O1trace.thread "mina_lib" (fun () ->
          let in_memory_reverse_structured_log_messages_for_integration_test =
            ref (0, [], false)
          in
          if not (List.is_empty config.start_filtered_logs) then
            (* Start the filtered logs, if requested. *)
            Or_error.ok_exn
            @@ start_filtered_log ~commit_id
                 in_memory_reverse_structured_log_messages_for_integration_test
                 config.start_filtered_logs ;
          let%bind proof_cache_db = initialize_proof_cache_db config in
          let%bind zkapp_vk_cache_db = initialize_zkapp_vk_cache_db config in
          let module Context =
          (val context ~proof_cache_db ~commit_id config)
          in
          let%bind prover =
            Monitor.try_with ~here:[%here]
              ~rest:
                (`Call
                  (fun exn ->
                    let err = Error.of_exn ~backtrace:`Get exn in
                    [%log' warn config.logger]
                      "unhandled exception from daemon-side prover server: $exn"
                      ~metadata:[ ("exn", Error_json.error_to_yojson err) ] ) )
              (fun () ->
                O1trace.thread "manage_prover_subprocess" (fun () ->
                    let%bind prover =
                      Prover.create ~commit_id ~logger:config.logger
                        ~enable_internal_tracing:
                          (Internal_tracing.is_enabled ())
                        ~internal_trace_filename:"prover-internal-trace.jsonl"
                        ~proof_level:config.precomputed_values.proof_level
                        ~constraint_constants ~pids:config.pids
                        ~conf_dir:config.conf_dir ()
                    in
                    let%map () = set_itn_data (module Prover) prover in
                    prover ) )
            >>| Result.ok_exn
          in
          let%bind verifier =
            Monitor.try_with ~here:[%here]
              ~rest:
                (`Call
                  (fun exn ->
                    let err = Error.of_exn ~backtrace:`Get exn in
                    [%log' warn config.logger]
                      "unhandled exception from daemon-side verifier server: \
                       $exn"
                      ~metadata:[ ("exn", Error_json.error_to_yojson err) ] ) )
              (fun () ->
                O1trace.thread "manage_verifier_subprocess" (fun () ->
                    let%bind blockchain_verification_key =
                      Prover.get_blockchain_verification_key prover
                      >>| Or_error.ok_exn
                    in
                    let%bind transaction_verification_key =
                      Prover.get_transaction_verification_key prover
                      >>| Or_error.ok_exn
                    in
                    let%bind verifier =
                      Verifier.create ~commit_id ~logger:config.logger
                        ~enable_internal_tracing:
                          (Internal_tracing.is_enabled ())
                        ~internal_trace_filename:"verifier-internal-trace.jsonl"
                        ~proof_level:config.precomputed_values.proof_level
                        ~pids:config.pids ~conf_dir:(Some config.conf_dir)
                        ~blockchain_verification_key
                        ~transaction_verification_key ()
                    in
                    let%map () = set_itn_data (module Verifier) verifier in
                    verifier ) )
            >>| Result.ok_exn
          in
          (* This setup is required for the dynamic enabling/disabling of internal
             tracing to also work with the verifier and prover sub-processes. *)
          Internal_tracing.register_toggle_callback (fun enabled ->
              let%map result =
                Verifier.toggle_internal_tracing verifier enabled
              in
              Or_error.iter_error result ~f:(fun error ->
                  [%log' warn config.logger]
                    "Failed to toggle verifier internal tracing: $error"
                    ~metadata:[ ("error", `String (Error.to_string_hum error)) ] ) ) ;
          Internal_tracing.register_toggle_callback (fun enabled ->
              let%map result = Prover.toggle_internal_tracing prover enabled in
              Or_error.iter_error result ~f:(fun error ->
                  [%log' warn config.logger]
                    "Failed to toggle prover internal tracing: $error"
                    ~metadata:[ ("error", `String (Error.to_string_hum error)) ] ) ) ;
          let%bind vrf_evaluator =
            Monitor.try_with ~here:[%here]
              ~rest:
                (`Call
                  (fun exn ->
                    let err = Error.of_exn ~backtrace:`Get exn in
                    [%log' warn config.logger]
                      "unhandled exception from daemon-side vrf evaluator \
                       server: $exn"
                      ~metadata:[ ("exn", Error_json.error_to_yojson err) ] ) )
              (fun () ->
                O1trace.thread "manage_vrf_evaluator_subprocess" (fun () ->
                    Vrf_evaluator.create ~commit_id ~constraint_constants
                      ~pids:config.pids ~logger:config.logger
                      ~conf_dir:config.conf_dir ~consensus_constants
                      ~keypairs:config.block_production_keypairs ) )
            >>| Result.ok_exn
          in
          let snark_worker =
            Option.value_map config.snark_worker_config.initial_snark_worker_key
              ~default:(`Off config.snark_work_fee) ~f:(fun public_key ->
                `On
                  ( { public_key
                    ; process = Ivar.create ()
                    ; kill_ivar = Ivar.create ()
                    }
                  , config.snark_work_fee ) )
          in
          let%bind uptime_snark_worker_opt =
            (* if uptime URL provided, run uptime service SNARK worker *)
            Option.value_map config.uptime_url ~default:(return None)
              ~f:(fun _url ->
                Monitor.try_with ~here:[%here]
                  ~rest:
                    (`Call
                      (fun exn ->
                        let err = Error.of_exn ~backtrace:`Get exn in
                        [%log' fatal config.logger]
                          "unhandled exception when creating uptime service \
                           SNARK worker: $exn, terminating daemon"
                          ~metadata:[ ("exn", Error_json.error_to_yojson err) ] ;
                        (* make sure Async shutdown handlers are called *)
                        don't_wait_for (Async.exit 1) ) )
                  (fun () ->
                    O1trace.thread "manage_uptime_snark_worker_subprocess"
                      (fun () ->
                        Uptime_service.Uptime_snark_worker.create
                          ~constraint_constants:
                            config.precomputed_values.constraint_constants
                          ~logger:config.logger ~pids:config.pids ) )
                >>| Result.ok )
          in
          log_snark_coordinator_warning config snark_worker ;
          Protocol_version.set_proposed_opt config.proposed_protocol_version_opt ;
          let log_rate_limiter_occasionally rl ~label =
            let t = Time.Span.of_min 1. in
            every t (fun () ->
                [%log' debug config.logger]
                  ~metadata:
                    [ ("rate_limiter", Network_pool.Rate_limiter.summary rl) ]
                  !"%s $rate_limiter" label )
          in
          let producer_transition_reader, producer_transition_writer =
            Strict_pipe.create Synchronous
          in
          let frontier_broadcast_pipe_r, frontier_broadcast_pipe_w =
            Broadcast_pipe.create None
          in
          let get_current_frontier () =
            Broadcast_pipe.Reader.peek frontier_broadcast_pipe_r
          in
          Exit_handlers.register_async_shutdown_handler ~logger:config.logger
            ~description:"Close transition frontier, if exists" (fun () ->
              match get_current_frontier () with
              | None ->
                  Deferred.unit
              | Some frontier ->
                  Transition_frontier.close ~loc:__LOC__ frontier ) ;
          (* knot-tying hacks so we can pass a get_node_status function before net, Mina_lib.t created *)
          let sync_status_ref = ref None in
          let get_node_status (net : Mina_networking.t) =
            O1trace.thread "handle_request_get_node_status" (fun () ->
                let node_ip_addr =
                  config.gossip_net_params.addrs_and_ports.external_ip
                in
                let peer_opt = config.gossip_net_params.addrs_and_ports.peer in
                let node_peer_id =
                  Option.value_map peer_opt ~default:"<UNKNOWN>" ~f:(fun peer ->
                      peer.peer_id )
                in
                if config.disable_node_status then
                  Deferred.return
                  @@ Error
                       (Error.of_string
                          (sprintf
                             !"Node with IP address=%{sexp: Unix.Inet_addr.t}, \
                               peer ID=%s, node status is disabled"
                             node_ip_addr node_peer_id ) )
                else
                  let ( protocol_state_hash
                      , best_tip_opt
                      , k_block_hashes_and_timestamps ) =
                    match get_current_frontier () with
                    | None ->
                        ( config.precomputed_values.protocol_state_with_hashes
                            .hash
                            .state_hash
                        , None
                        , [] )
                    | Some frontier ->
                        let tip = Transition_frontier.best_tip frontier in
                        let protocol_state_hash =
                          Transition_frontier.Breadcrumb.state_hash tip
                        in
                        let k_breadcrumbs =
                          Transition_frontier.root frontier
                          :: Transition_frontier.best_tip_path frontier
                        in
                        let k_block_hashes_and_timestamps =
                          List.map k_breadcrumbs ~f:(fun bc ->
                              ( Transition_frontier.Breadcrumb.state_hash bc
                              , Option.value_map
                                  (Transition_frontier.Breadcrumb
                                   .transition_receipt_time bc )
                                  ~default:"no timestamp available"
                                  ~f:
                                    (Time.to_string_iso8601_basic
                                       ~zone:Time.Zone.utc ) ) )
                        in
                        ( protocol_state_hash
                        , Some tip
                        , k_block_hashes_and_timestamps )
                  in
                  let%bind peers = Mina_networking.peers net in
                  let open Deferred.Or_error.Let_syntax in
                  let%map sync_status =
                    match !sync_status_ref with
                    | None ->
                        Deferred.return (Ok `Offline)
                    | Some status ->
                        Deferred.return
                          (Mina_incremental.Status.Observer.value status)
                  in
                  let block_producers =
                    config.block_production_keypairs
                    |> Public_key.Compressed.Set.map ~f:snd
                    |> Set.to_list
                  in
                  let ban_statuses =
                    Trust_system.Peer_trust.peer_statuses config.trust_system
                  in
                  let git_commit = commit_id_short in
                  let uptime_minutes =
                    let now = Time.now () in
                    let minutes_float =
                      Time.diff now config.start_time |> Time.Span.to_min
                    in
                    (* if rounding fails, just convert *)
                    Option.value_map
                      (Float.iround_nearest minutes_float)
                      ~f:Fn.id
                      ~default:(Float.to_int minutes_float)
                  in
                  let block_height_opt =
                    match best_tip_opt with
                    | None ->
                        None
                    | Some tip ->
                        let state =
                          Transition_frontier.Breadcrumb.protocol_state tip
                        in
                        let consensus_state =
                          state |> Mina_state.Protocol_state.consensus_state
                        in
                        Some
                          ( Mina_numbers.Length.to_int
                          @@ Consensus.Data.Consensus_state.blockchain_length
                               consensus_state )
                  in
                  Mina_networking.Node_status.Stable.V2.
                    { node_ip_addr
                    ; node_peer_id
                    ; sync_status
                    ; peers
                    ; block_producers
                    ; protocol_state_hash
                    ; ban_statuses
                    ; k_block_hashes_and_timestamps
                    ; git_commit
                    ; uptime_minutes
                    ; block_height_opt
                    } )
          in
          let slot_tx_end =
            Runtime_config.slot_tx_end config.precomputed_values.runtime_config
          in
          let txn_pool_config =
            Network_pool.Transaction_pool.Resource_pool.make_config ~verifier
              ~trust_system:config.trust_system
              ~pool_max_size:
                config.precomputed_values.genesis_constants.txpool_max_size
              ~genesis_constants:config.precomputed_values.genesis_constants
              ~slot_tx_end ~vk_cache_db:zkapp_vk_cache_db ~proof_cache_db
          in
          let first_received_message_signal = Ivar.create () in
          let online_status, notify_online_impl =
            online_broadcaster
              ~constraint_constants:Context.constraint_constants
              config.time_controller
          in
          let on_first_received_message ~f =
            Ivar.read first_received_message_signal >>| f
          in

          (* TODO remove the line below after making sure notification will not lead
             to a stale lock *)
          let notify_online () =
            Ivar.fill_if_empty first_received_message_signal () ;
            notify_online_impl () |> don't_wait_for ;
            Deferred.unit
          in
          let transaction_pool, tx_remote_sink, tx_local_sink =
            (* make transaction pool return writer for local and incoming diffs *)
            Network_pool.Transaction_pool.create ~config:txn_pool_config
              ~constraint_constants ~consensus_constants
              ~time_controller:config.time_controller ~logger:config.logger
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
              ~on_remote_push:notify_online
              ~log_gossip_heard:
                config.net_config.log_gossip_heard.transaction_pool_diff
              ~block_window_duration
          in
          let snark_pool_config =
            Network_pool.Snark_pool.Resource_pool.make_config ~verifier
              ~trust_system:config.trust_system
              ~disk_location:config.snark_pool_disk_location ~proof_cache_db
          in
          let snark_pool, snark_remote_sink, snark_local_sink =
            Network_pool.Snark_pool.create ~config:snark_pool_config
              ~constraint_constants ~consensus_constants
              ~time_controller:config.time_controller ~logger:config.logger
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
              ~on_remote_push:notify_online
              ~log_gossip_heard:
                config.net_config.log_gossip_heard.snark_pool_diff
              ~block_window_duration
          in
          let block_reader, block_sink =
            Transition_handler.Block_sink.create
              { logger = config.logger
              ; slot_duration_ms =
                  config.precomputed_values.consensus_constants.slot_duration_ms
              ; on_push = notify_online
              ; log_gossip_heard = config.net_config.log_gossip_heard.new_state
              ; time_controller = Context.time_controller
              ; consensus_constants
              ; genesis_constants = config.precomputed_values.genesis_constants
              ; constraint_constants
              }
          in
          let snark_jobs_state =
            Work_selector.State.init
              ~reassignment_wait:config.work_reassignment_wait
              ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
              ~logger:config.logger
          in
          let sinks = (block_sink, tx_remote_sink, snark_remote_sink) in
          let%bind net =
            O1trace.thread "mina_networking" (fun () ->
                Mina_networking.create
                  (module Context)
                  config.net_config ~sinks
                  ~get_transition_frontier:(fun () ->
                    Broadcast_pipe.Reader.peek frontier_broadcast_pipe_r )
                  ~get_snark_pool:(fun () -> Some snark_pool)
                  ~snark_job_state:(fun () -> Some snark_jobs_state)
                  ~get_node_status )
          in
          let user_command_input_reader, user_command_input_writer =
            Strict_pipe.(create ~name:"local user transactions" Synchronous)
          in
          let block_produced_bvar = Bvar.create () in
          (*Read from user_command_input_reader that has the user command inputs from client, infer nonce, create user command, and write it to the pipe consumed by the network pool*)
          Strict_pipe.Reader.iter user_command_input_reader
            ~f:(fun (inputs, result_cb, get_current_nonce, get_account) ->
              match inputs with
              | Signed_command_inputs uc_inputs -> (
                  match%bind
                    User_command_input.to_user_commands ~get_current_nonce
                      ~get_account ~constraint_constants ~logger:config.logger
                      uc_inputs
                  with
                  | Ok signed_commands ->
                      if List.is_empty signed_commands then (
                        result_cb
                          (Error (Error.of_string "No user commands to send")) ;
                        Deferred.unit )
                      else
                        (*callback for the result from transaction_pool.apply_diff*)
                        Network_pool.Transaction_pool.Local_sink.push
                          tx_local_sink
                          ( List.map signed_commands ~f:(fun c ->
                                User_command.Signed_command c )
                          , result_cb )
                  | Error e ->
                      [%log' error config.logger]
                        "Failed to submit user commands: $error"
                        ~metadata:[ ("error", Error_json.error_to_yojson e) ] ;
                      result_cb (Error e) ;
                      Deferred.unit )
              | Zkapp_command_command_inputs zkapp_commands ->
                  (* TODO: here, submit a Zkapp_command.t, which includes a nonce
                     allow the nonce to be omitted, and infer it, as done
                     for user command inputs
                  *)
                  (* too-big Zkapp_command.t's were filtered when writing to the user command pipe *)
                  Network_pool.Transaction_pool.Local_sink.push tx_local_sink
                    ( List.map zkapp_commands ~f:(fun zkapp_command ->
                          User_command.Zkapp_command zkapp_command )
                    , result_cb ) )
          |> Deferred.don't_wait_for ;
          let most_recent_valid_block_reader, most_recent_valid_block_writer =
            Broadcast_pipe.create
              ( Mina_block.genesis_header
                  ~precomputed_values:config.precomputed_values
              |> Validation.reset_frontier_dependencies_validation
              |> Validation.reset_staged_ledger_diff_validation )
          in
          let get_most_recent_valid_block () =
            Broadcast_pipe.Reader.peek most_recent_valid_block_reader
          in

          let transaction_resource_pool =
            Network_pool.Transaction_pool.resource_pool transaction_pool
          in
          let transaction_pool_proxy : Staged_ledger.transaction_pool_proxy =
            { find_by_hash =
                Network_pool.Transaction_pool.Resource_pool.find_by_hash
                  transaction_resource_pool
            }
          in

          let valid_transitions, initialization_finish_signal =
            Transition_router.run
              ~context:(module Context)
              ~trust_system:config.trust_system ~verifier ~network:net
              ~is_seed:config.is_seed ~is_demo_mode:config.demo_mode
              ~time_controller:config.time_controller
              ~consensus_local_state:config.consensus_local_state
              ~persistent_root_location:config.persistent_root_location
              ~persistent_frontier_location:config.persistent_frontier_location
              ~get_current_frontier
              ~frontier_broadcast_writer:frontier_broadcast_pipe_w
              ~catchup_mode:`Super ~network_transition_reader:block_reader
              ~producer_transition_reader ~get_most_recent_valid_block
              ~most_recent_valid_block_writer
              ~get_completed_work:
                (Network_pool.Snark_pool.get_completed_work snark_pool)
              ~notify_online ~transaction_pool_proxy ()
          in
          let ( valid_transitions_for_network
              , valid_transitions_for_api
              , new_blocks ) =
            let network_pipe, downstream_pipe =
              Strict_pipe.Reader.Fork.two valid_transitions
            in
            let api_pipe, new_blocks_pipe =
              Strict_pipe.Reader.(
                Fork.two
                  (map downstream_pipe ~f:(fun (`Transition t, _, _) -> t)))
            in
            (network_pipe, api_pipe, new_blocks_pipe)
          in
          O1trace.background_thread "broadcast_transaction_pool_diffs"
            (fun () ->
              let rl = Network_pool.Transaction_pool.create_rate_limiter () in
              log_rate_limiter_occasionally rl ~label:"broadcast_transactions" ;
              Linear_pipe.iter
                (Network_pool.Transaction_pool.broadcasts transaction_pool)
                ~f:(fun Network_pool.With_nonce.{ message; nonce } ->
                  (* the commands had valid sizes when added to the transaction pool
                     don't need to check sizes again for broadcast
                  *)
                  let%bind () =
                    send_resource_pool_diff_or_wait ~rl
                      ~diff_score:
                        Network_pool.Transaction_pool.Resource_pool.Diff.score
                      ~max_per_15_seconds:
                        Network_pool.Transaction_pool.Resource_pool.Diff
                        .max_per_15_seconds message
                  in
                  Mina_networking.broadcast_transaction_pool_diff ~nonce net
                    message ) ) ;
          O1trace.background_thread "broadcast_blocks" (fun () ->
              Strict_pipe.Reader.iter_without_pushback
                valid_transitions_for_network
                ~f:(fun
                     (`Transition transition, `Source source, `Valid_cb valid_cb)
                   ->
                  let hash =
                    Mina_block.Validated.forget transition
                    |> State_hash.With_state_hashes.state_hash
                  in
                  let consensus_state =
                    transition |> Mina_block.Validated.header
                    |> Header.protocol_state
                    |> Mina_state.Protocol_state.consensus_state
                  in
                  let now =
                    let open Block_time in
                    now config.time_controller |> to_span_since_epoch
                    |> Span.to_ms
                  in
                  match
                    Consensus.Hooks.received_at_valid_time
                      ~constants:consensus_constants ~time_received:now
                      consensus_state
                  with
                  | Ok () -> (
                      match source with
                      | `Gossip ->
                          [%str_log' info config.logger]
                            ~metadata:
                              [ ( "external_transition"
                                , Mina_block.Validated.to_yojson transition )
                              ]
                            (Rebroadcast_transition { state_hash = hash }) ;
                          (*send callback to libp2p to forward the gossiped transition*)
                          Option.iter
                            ~f:
                              (Fn.flip
                                 Mina_net2.Validation_callback
                                 .fire_if_not_already_fired `Accept )
                            valid_cb
                      | `Internal ->
                          (*Send callback to publish the new block. Don't log rebroadcast message if it is internally generated; There is a broadcast log*)
                          Option.iter
                            ~f:
                              (Fn.flip
                                 Mina_net2.Validation_callback
                                 .fire_if_not_already_fired `Accept )
                            valid_cb
                      | `Catchup ->
                          (*Noop for directly downloaded transitions*)
                          Option.iter
                            ~f:
                              (Fn.flip
                                 Mina_net2.Validation_callback
                                 .fire_if_not_already_fired `Accept )
                            valid_cb )
                  | Error reason -> (
                      let timing_error_json =
                        match reason with
                        | `Too_early ->
                            `String "too early"
                        | `Too_late slots ->
                            `String (sprintf "%Lu slots too late" slots)
                      in
                      let metadata =
                        [ ("state_hash", State_hash.to_yojson hash)
                        ; ("block", Mina_block.Validated.to_yojson transition)
                        ; ("timing", timing_error_json)
                        ]
                      in
                      Option.iter
                        ~f:
                          (Fn.flip
                             Mina_net2.Validation_callback
                             .fire_if_not_already_fired `Reject )
                        valid_cb ;
                      match source with
                      | `Catchup ->
                          ()
                      | `Internal ->
                          [%log' error config.logger] ~metadata
                            "Internally generated block $state_hash cannot be \
                             rebroadcast because it's not a valid time to do \
                             so ($timing)"
                      | `Gossip ->
                          [%log' warn config.logger] ~metadata
                            "Not rebroadcasting block $state_hash because it \
                             was received $timing" ) ) ) ;
          (* FIXME #4093: augment ban_notifications with a Peer.ID so we can implement ban_notify
             trace_task "ban notification loop" (fun () ->
              Linear_pipe.iter (Mina_networking.ban_notification_reader net)
                ~f:(fun notification ->
                  let open Gossip_net in
                  let peer = notification.banned_peer in
                  let banned_until = notification.banned_until in
                  (* if RPC call fails, will be logged in gossip net code *)
                  let%map _ =
                    Mina_networking.ban_notify net peer banned_until
                  in
                  () ) ) ; *)
          don't_wait_for
            (Linear_pipe.iter
               (Mina_networking.ban_notification_reader net)
               ~f:(Fn.const Deferred.unit) ) ;

          let%map wallets =
            match wallets with
            | Some wallets ->
                return wallets
            | None ->
                Secrets.Wallets.load ~logger:config.logger
                  ~disk_location:config.wallets_disk_location
          in

          O1trace.background_thread "broadcast_snark_pool_diffs" (fun () ->
              let rl = Network_pool.Snark_pool.create_rate_limiter () in
              log_rate_limiter_occasionally rl ~label:"broadcast_snark_work" ;
              Linear_pipe.iter (Network_pool.Snark_pool.broadcasts snark_pool)
                ~f:(fun Network_pool.With_nonce.{ message; nonce } ->
                  let%bind () =
                    send_resource_pool_diff_or_wait ~rl
                      ~diff_score:
                        Network_pool.Snark_pool.Resource_pool.Diff.score
                      ~max_per_15_seconds:
                        Network_pool.Snark_pool.Resource_pool.Diff
                        .max_per_15_seconds message
                  in
                  Mina_networking.broadcast_snark_pool_diff ~nonce net message ) ) ;
          Option.iter config.archive_process_location
            ~f:(fun archive_process_port ->
              [%log' info config.logger]
                "Communicating with the archive process"
                ~metadata:
                  [ ( "Host"
                    , `String (Host_and_port.host archive_process_port.value) )
                  ; ( "Port"
                    , `Int (Host_and_port.port archive_process_port.value) )
                  ] ;
              Archive_client.run ~logger:config.logger
                ~precomputed_values:config.precomputed_values
                ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
                archive_process_port ) ;
          let precomputed_block_writer =
            ref
              ( Option.map config.precomputed_blocks_path ~f:(fun path ->
                    `Path path )
              , if config.log_precomputed_blocks then Some `Log else None )
          in
          let subscriptions =
            Mina_subscriptions.create ~logger:config.logger
              ~constraint_constants ~new_blocks ~wallets
              ~transition_frontier:frontier_broadcast_pipe_r
              ~is_storing_all:config.is_archive_rocksdb
              ~upload_blocks_to_gcloud:config.upload_blocks_to_gcloud
              ~time_controller:config.time_controller ~precomputed_block_writer
          in
          let open Mina_incremental.Status in
          let transition_frontier_incr =
            Var.watch @@ of_broadcast_pipe frontier_broadcast_pipe_r
          in
          let transition_frontier_and_catchup_signal_incr =
            transition_frontier_incr
            >>= function
            | Some transition_frontier ->
                of_broadcast_pipe Ledger_catchup.Catchup_jobs.reader
                |> Var.watch
                >>| fun catchup_signal ->
                Some (transition_frontier, catchup_signal)
            | None ->
                return None
          in
          let sync_status =
            create_sync_status_observer ~logger:config.logger
              ~genesis_timestamp:
                config.precomputed_values.genesis_constants.protocol
                  .genesis_state_timestamp
              ~net ~is_seed:config.is_seed ~demo_mode:config.demo_mode
              ~transition_frontier_and_catchup_signal_incr
              ~online_status_incr:(Var.watch @@ of_broadcast_pipe online_status)
              ~first_connection_incr:
                ( Var.watch @@ of_deferred
                @@ Mina_networking.on_first_connect net ~f:Fn.id )
              ~first_message_incr:
                (Var.watch @@ of_deferred @@ on_first_received_message ~f:Fn.id)
          in
          (* tie other knot *)
          sync_status_ref := Some sync_status ;
          O1trace.background_thread "fetch_completed_snarks" (fun () ->
              let open Deferred.Let_syntax in
              let last_sync_status = ref `Offline in
              let equal_status
                  (s1 :
                    [> `Catchup
                    | `Connecting
                    | `Listening
                    | `Offline
                    | `Synced
                    | `Bootstrap ] )
                  (s2 :
                    [> `Catchup
                    | `Connecting
                    | `Listening
                    | `Offline
                    | `Synced
                    | `Bootstrap ] ) =
                match (s1, s2) with
                | `Catchup, `Catchup ->
                    true
                | `Connecting, `Connecting ->
                    true
                | `Listening, `Listening ->
                    true
                | `Offline, `Offline ->
                    true
                | `Synced, `Synced ->
                    true
                | `Bootstrap, `Bootstrap ->
                    true
                | _ ->
                    false
              in
              let to_yojson_status = function
                | `Catchup ->
                    `String "Catchup"
                | `Connecting ->
                    `String "Connecting"
                | `Listening ->
                    `String "Listening"
                | `Offline ->
                    `String "Offline"
                | `Synced ->
                    `String "Synced"
                | `Bootstrap ->
                    `String "Bootstrap"
              in
              let rec loop () =
                let status = !last_sync_status in
                (* log the status with info *)
                [%log' debug config.logger] "Current sync status: $status"
                  ~metadata:[ ("status", to_yojson_status status) ] ;
                if Option.is_none !sync_status_ref then loop ()
                else
                  match
                    Mina_incremental.Status.Observer.value
                      (Option.value_exn !sync_status_ref)
                  with
                  | Ok (`Offline as s) | Ok (`Bootstrap as s) ->
                      let%bind () = after (Time.Span.of_sec 1.) in
                      last_sync_status := s ;
                      loop ()
                  | Ok `Synced
                    when equal_status !last_sync_status `Catchup
                         || equal_status !last_sync_status `Bootstrap ->
                      [%log' debug config.logger]
                        "Synced, fetching completed snarks" ;
                      let received_block =
                        get_most_recent_valid_block ()
                        |> Validation.header
                        |> Mina_block.Header.blockchain_length
                      in
                      fetch_completed_snarks
                        (module Context)
                        snark_pool net received_block get_current_frontier
                  | Ok (`Catchup as s)
                  | Ok (`Listening as s)
                  | Ok (`Connecting as s)
                  | Ok (`Synced as s) ->
                      let%bind () = after (Time.Span.of_sec 1.) in
                      last_sync_status := s ;
                      loop ()
                  | Error _e ->
                      loop ()
              in
              loop () ) ;
          { config
          ; next_producer_timing = None
          ; processes =
              { prover
              ; verifier
              ; snark_worker
              ; uptime_snark_worker_opt
              ; vrf_evaluator
              }
          ; initialization_finish_signal
          ; components =
              { net
              ; transaction_pool
              ; snark_pool
              ; transition_frontier = frontier_broadcast_pipe_r
              ; most_recent_valid_block = most_recent_valid_block_reader
              ; block_produced_bvar
              }
          ; pipes =
              { validated_transitions_reader = valid_transitions_for_api
              ; producer_transition_writer
              ; user_command_input_writer
              ; tx_local_sink
              ; snark_local_sink
              }
          ; wallets
          ; coinbase_receiver = ref config.coinbase_receiver
          ; snark_job_state = snark_jobs_state
          ; subscriptions
          ; sync_status
          ; precomputed_block_writer
          ; block_production_status = ref `Free
          ; in_memory_reverse_structured_log_messages_for_integration_test
          ; vrf_evaluation_state = Block_producer.Vrf_evaluation_state.create ()
          ; commit_id
          ; proof_cache_db
          } ) )

let net { components = { net; _ }; _ } = net

let runtime_config t = t.config.precomputed_values.runtime_config

let start_filtered_log
    ({ in_memory_reverse_structured_log_messages_for_integration_test
     ; commit_id
     ; _
     } :
      t ) (structured_log_ids : string list) =
  start_filtered_log ~commit_id
    in_memory_reverse_structured_log_messages_for_integration_test
    structured_log_ids

let get_filtered_log_entries
    ({ in_memory_reverse_structured_log_messages_for_integration_test; _ } : t)
    (idx : int) =
  let rec get_from_idx curr_idx rev_messages output =
    if idx < curr_idx then
      match rev_messages with
      | [] ->
          output
      | msg :: rev_messages ->
          get_from_idx (curr_idx - 1) rev_messages (msg :: output)
    else output
  in
  let curr_idx, messages, is_started =
    !in_memory_reverse_structured_log_messages_for_integration_test
  in
  (get_from_idx curr_idx messages [], is_started)

let prover { processes = { prover; _ }; _ } = prover

let vrf_evaluator { processes = { vrf_evaluator; _ }; _ } = vrf_evaluator

let genesis_ledger t = Genesis_proof.genesis_ledger t.config.precomputed_values

let get_transition_frontier (t : t) =
  transition_frontier t |> Pipe_lib.Broadcast_pipe.Reader.peek
  |> Result.of_option ~error:"Could not obtain transition frontier"

let best_chain_block_by_height (t : t) height =
  let open Result.Let_syntax in
  let%bind transition_frontier = get_transition_frontier t in
  Transition_frontier.best_tip_path transition_frontier
  |> List.find ~f:(fun bc ->
         let validated_transition =
           Transition_frontier.Breadcrumb.validated_transition bc
         in
         let block_height =
           Mina_block.(
             blockchain_length @@ With_hash.data
             @@ Validated.forget validated_transition)
         in
         Unsigned.UInt32.equal block_height height )
  |> Result.of_option
       ~error:
         (sprintf "Could not find block in transition frontier with height %s"
            (Unsigned.UInt32.to_string height) )

let best_chain_block_by_state_hash (t : t) hash =
  let open Result.Let_syntax in
  let%bind transition_frontier = get_transition_frontier t in
  Transition_frontier.find transition_frontier hash
  |> Result.of_option
       ~error:
         (sprintf "Block with state hash %s not found in transition frontier"
            (State_hash.to_base58_check hash) )

let zkapp_cmd_limit t = t.config.zkapp_cmd_limit

let proof_cache_db t = t.proof_cache_db
