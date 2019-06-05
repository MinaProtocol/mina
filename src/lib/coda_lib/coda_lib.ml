[%%import
"../../config.mlh"]

open Core_kernel
open Async_kernel
open Coda_base
open Pipe_lib
open Strict_pipe
open Signature_lib
open Coda_state
open O1trace
open Otp_lib

(* used in error below to allow pattern-match against error *)
let refused_answer_query_string = "Refused to answer_query"

module Make (Inputs : Intf.Inputs) = struct
  open Auxiliary_database
  open Inputs
  module Ledger_transfer = Ledger_transfer.Make (Ledger) (Ledger.Db)
  module Subscriptions = Coda_subscriptions.Make (Inputs)

  type t =
    { propose_keypairs:
        (Agent.read_write Agent.flag, Keypair.And_compressed_pk.Set.t) Agent.t
    ; snark_worker_key: Public_key.Compressed.Stable.V1.t option
    ; net: Net.t
    ; verifier: Verifier.t
    ; wallets: Secrets.Wallets.t
    ; transaction_pool: Transaction_pool.t
    ; snark_pool: Snark_pool.t
    ; transition_frontier: Transition_frontier.t option Broadcast_pipe.Reader.t
    ; validated_transitions:
        (External_transition.Validated.t, State_hash.t) With_hash.t
        Strict_pipe.Reader.t
    ; proposer_transition_writer:
        ( Transition_frontier.Breadcrumb.t
        , synchronous
        , unit Deferred.t )
        Writer.t
    ; logger: Logger.t
    ; trust_system: Trust_system.t
    ; mutable seen_jobs: Work_selector.State.t
    ; transaction_database: Transaction_database.t
    ; external_transition_database: External_transition_database.t
    ; receipt_chain_database: Coda_base.Receipt_chain_database.t
    ; staged_ledger_transition_backup_capacity: int
    ; external_transitions_writer:
        (External_transition.t Envelope.Incoming.t * Block_time.t)
        Pipe.Writer.t
    ; time_controller: Block_time.Controller.t
    ; snark_work_fee: Currency.Fee.t
    ; consensus_local_state: Consensus.Data.Local_state.t
    ; subscriptions: Subscriptions.t }

  let peek_frontier frontier_broadcast_pipe =
    Broadcast_pipe.Reader.peek frontier_broadcast_pipe
    |> Result.of_option
         ~error:
           (Error.of_string
              "Cannot retrieve transition frontier now. Bootstrapping right \
               now.")

  let wallets t = t.wallets

  let snark_worker_key t = t.snark_worker_key

  let propose_public_keys t =
    Consensus.Data.Local_state.current_proposers t.consensus_local_state

  let replace_propose_keypairs t kps = Agent.update t.propose_keypairs kps

  let best_tip_opt t =
    let open Option.Let_syntax in
    let%map frontier = Broadcast_pipe.Reader.peek t.transition_frontier in
    Transition_frontier.best_tip frontier

  let transition_frontier t = t.transition_frontier

  let root_length_opt t =
    let open Option.Let_syntax in
    let%map frontier = Broadcast_pipe.Reader.peek t.transition_frontier in
    Transition_frontier.root_length frontier

  let best_staged_ledger_opt t =
    let open Option.Let_syntax in
    let%map tip = best_tip_opt t in
    Transition_frontier.Breadcrumb.staged_ledger tip

  let best_protocol_state_opt t =
    let open Option.Let_syntax in
    let%map tip = best_tip_opt t in
    Transition_frontier.Breadcrumb.transition_with_hash tip
    |> With_hash.data |> External_transition.Validated.protocol_state

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

  module Incr = struct
    open Coda_incremental.Status

    let online_status t = of_broadcast_pipe @@ Net.online_status t.net

    let transition_frontier t = of_broadcast_pipe @@ t.transition_frontier
  end

  [%%if
  mock_frontend_data]

  let sync_status _ =
    let variable = Coda_incremental.Status.Var.create `Offline in
    let incr = Coda_incremental.Status.Var.watch variable in
    let rec loop () =
      let%bind () = Async.after (Core.Time.Span.of_sec 5.0) in
      let current_value = Coda_incremental.Status.Var.value variable in
      let new_sync_status =
        List.random_element_exn
          ( match current_value with
          | `Offline ->
              [`Bootstrap; `Synced]
          | `Synced ->
              [`Offline; `Bootstrap]
          | `Bootstrap ->
              [`Offline; `Synced] )
      in
      Coda_incremental.Status.Var.set variable new_sync_status ;
      Coda_incremental.Status.stabilize () ;
      loop ()
    in
    let observer = Coda_incremental.Status.observe incr in
    Coda_incremental.Status.stabilize () ;
    don't_wait_for @@ loop () ;
    observer

  [%%else]

  let sync_status t =
    let open Coda_incremental.Status in
    let transition_frontier_incr = Var.watch @@ Incr.transition_frontier t in
    let incremental_status =
      map2
        (Var.watch @@ Incr.online_status t)
        transition_frontier_incr
        ~f:(fun online_status active_status ->
          match online_status with
          | `Offline ->
              `Offline
          | `Online ->
              Option.value_map active_status ~default:`Bootstrap
                ~f:(Fn.const `Synced) )
    in
    let observer = observe incremental_status in
    stabilize () ; observer

  [%%endif]

  let visualize_frontier ~filename =
    compose_of_option
    @@ fun t ->
    let open Option.Let_syntax in
    let%map frontier = Broadcast_pipe.Reader.peek t.transition_frontier in
    Transition_frontier.visualize ~filename frontier

  let best_staged_ledger = compose_of_option best_staged_ledger_opt

  let best_protocol_state = compose_of_option best_protocol_state_opt

  let best_ledger = compose_of_option best_ledger_opt

  let get_ledger t staged_ledger_hash =
    let open Deferred.Or_error.Let_syntax in
    let%bind frontier =
      Deferred.return (t.transition_frontier |> peek_frontier)
    in
    match
      List.find_map (Transition_frontier.all_breadcrumbs frontier) ~f:(fun b ->
          let staged_ledger = Transition_frontier.Breadcrumb.staged_ledger b in
          if
            Staged_ledger_hash.equal
              (Staged_ledger.hash staged_ledger)
              staged_ledger_hash
          then Some (Ledger.to_list (Staged_ledger.ledger staged_ledger))
          else None )
    with
    | Some x ->
        Deferred.return (Ok x)
    | None ->
        Deferred.Or_error.error_string
          "staged ledger hash not found in transition frontier"

  let seen_jobs t = t.seen_jobs

  let subscription t = t.subscriptions

  let set_seen_jobs t seen_jobs = t.seen_jobs <- seen_jobs

  let transaction_pool t = t.transaction_pool

  let transaction_database t = t.transaction_database

  let external_transition_database t = t.external_transition_database

  let snark_pool t = t.snark_pool

  let peers t = Net.peers t.net

  let initial_peers t = Net.initial_peers t.net

  let snark_work_fee t = t.snark_work_fee

  let receipt_chain_database t = t.receipt_chain_database

  let top_level_logger t = t.logger

  let staged_ledger_ledger_proof t =
    let open Option.Let_syntax in
    let%bind sl = best_staged_ledger_opt t in
    Staged_ledger.current_ledger_proof sl

  let validated_transitions t = t.validated_transitions

  let root_diff t =
    let root_diff_reader, root_diff_writer =
      Strict_pipe.create ~name:"root diff"
        (Buffered (`Capacity 30, `Overflow Crash))
    in
    don't_wait_for
      (Broadcast_pipe.Reader.iter t.transition_frontier ~f:(function
        | None ->
            Deferred.unit
        | Some frontier ->
            Broadcast_pipe.Reader.iter
              (Transition_frontier.root_diff_pipe frontier)
              ~f:(fun root_diff ->
                Strict_pipe.Writer.write root_diff_writer root_diff
                |> Deferred.return ) )) ;
    root_diff_reader

  let dump_tf t =
    peek_frontier t.transition_frontier
    |> Or_error.map ~f:Transition_frontier.visualize_to_string

  (** The [best_path coda] is the list of state hashes from the root to the best_tip in the transition frontier. It includes the root hash and the hash *)
  let best_path t =
    let open Option.Let_syntax in
    let%map tf = Broadcast_pipe.Reader.peek t.transition_frontier in
    let bt = Transition_frontier.best_tip tf in
    List.cons
      Transition_frontier.(root tf |> Breadcrumb.state_hash)
      (Transition_frontier.hash_path tf bt)

  module Config = struct
    (** If ledger_db_location is None, will auto-generate a db based on a UUID *)
    type t =
      { logger: Logger.t
      ; trust_system: Trust_system.t
      ; verifier: Verifier.t
      ; initial_propose_keypairs: Keypair.Set.t
      ; snark_worker_key: Public_key.Compressed.Stable.V1.t option
      ; net_config: Net.Config.t
      ; transaction_pool_disk_location: string
      ; snark_pool_disk_location: string
      ; wallets_disk_location: string
      ; ledger_db_location: string option
      ; transition_frontier_location: string option
      ; staged_ledger_transition_backup_capacity: int [@default 10]
      ; time_controller: Block_time.Controller.t
      ; receipt_chain_database: Coda_base.Receipt_chain_database.t
      ; transaction_database: Transaction_database.t
      ; external_transition_database: External_transition_database.t
      ; snark_work_fee: Currency.Fee.t
      ; monitor: Monitor.t option
      ; consensus_local_state: Consensus.Data.Local_state.t
            (* TODO: Pass banlist to modules discussed in Ban Reasons issue: https://github.com/CodaProtocol/coda/issues/852 *)
      }
    [@@deriving make]
  end

  let start t =
    Proposer.run ~logger:t.logger ~verifier:t.verifier
      ~trust_system:t.trust_system ~transaction_pool:t.transaction_pool
      ~get_completed_work:(Snark_pool.get_completed_work t.snark_pool)
      ~time_controller:t.time_controller
      ~keypairs:(Agent.read_only t.propose_keypairs)
      ~consensus_local_state:t.consensus_local_state
      ~frontier_reader:t.transition_frontier
      ~transition_writer:t.proposer_transition_writer

  let create_genesis_frontier (config : Config.t) =
    let consensus_local_state = config.consensus_local_state in
    let pending_coinbases = Pending_coinbase.create () |> Or_error.ok_exn in
    let empty_diff =
      { Staged_ledger_diff.diff=
          ( { completed_works= []
            ; user_commands= []
            ; coinbase= Staged_ledger_diff.At_most_two.Zero }
          , None )
      ; prev_hash=
          Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
            (Staged_ledger_hash.Aux_hash.of_bytes "")
            (Ledger.merkle_root Genesis_ledger.t)
            pending_coinbases
      ; creator= Account.public_key (snd (List.hd_exn Genesis_ledger.accounts))
      }
    in
    let genesis_protocol_state = With_hash.data Genesis_protocol_state.t in
    (* the genesis transition is assumed to be valid *)
    let (`I_swear_this_is_safe_see_my_comment first_transition) =
      External_transition.Validated.create_unsafe
        (External_transition.create ~protocol_state:genesis_protocol_state
           ~protocol_state_proof:Genesis.proof ~staged_ledger_diff:empty_diff)
    in
    let ledger_db =
      Ledger.Db.create ?directory_name:config.ledger_db_location ()
    in
    let root_snarked_ledger =
      Ledger_transfer.transfer_accounts ~src:Genesis.ledger ~dest:ledger_db
    in
    let snarked_ledger_hash =
      Frozen_ledger_hash.of_ledger_hash @@ Ledger.merkle_root Genesis.ledger
    in
    let%bind root_staged_ledger =
      match%map
        Staged_ledger.of_scan_state_and_ledger ~logger:config.logger
          ~verifier:config.verifier ~snarked_ledger_hash ~ledger:Genesis.ledger
          ~scan_state:(Staged_ledger.Scan_state.empty ())
          ~pending_coinbase_collection:pending_coinbases
      with
      | Ok staged_ledger ->
          staged_ledger
      | Error err ->
          Error.raise err
    in
    let%map frontier =
      Transition_frontier.create ~logger:config.logger
        ~root_transition:
          (With_hash.of_data first_transition
             ~hash_data:
               (Fn.compose Protocol_state.hash
                  External_transition.Validated.protocol_state))
        ~root_staged_ledger ~root_snarked_ledger ~consensus_local_state
    in
    (root_snarked_ledger, frontier)

  let create (config : Config.t) =
    let monitor = Option.value ~default:(Monitor.create ()) config.monitor in
    Async.Scheduler.within' ~monitor (fun () ->
        trace_task "coda" (fun () ->
            let external_transitions_reader, external_transitions_writer =
              Strict_pipe.create Synchronous
            in
            let proposer_transition_reader, proposer_transition_writer =
              Strict_pipe.create Synchronous
            in
            let net_ivar = Ivar.create () in
            let flush_capacity = 30 in
            let%bind persistence, ledger_db, transition_frontier =
              match config.transition_frontier_location with
              | None ->
                  let%map ledger_db, frontier =
                    create_genesis_frontier config
                  in
                  ( None
                  , Ledger_transfer.transfer_accounts ~src:Genesis.ledger
                      ~dest:ledger_db
                  , frontier )
              | Some transition_frontier_location -> (
                  match%bind
                    Async.Sys.file_exists transition_frontier_location
                  with
                  | `No | `Unknown ->
                      Logger.info config.logger ~module_:__MODULE__
                        ~location:__LOC__
                        !"Persistence database does not exist yet. Creating \
                          it at %s"
                        transition_frontier_location ;
                      let%bind () =
                        Async.Unix.mkdir transition_frontier_location
                      in
                      let persistence =
                        Transition_frontier_persistence.create
                          ~directory_name:transition_frontier_location
                          ~logger:config.logger ~flush_capacity
                          ~max_buffer_capacity:(4 * flush_capacity) ()
                      in
                      let%map root_snarked_ledger, frontier =
                        create_genesis_frontier config
                      in
                      (Some persistence, root_snarked_ledger, frontier)
                  | `Yes ->
                      let directory_name = transition_frontier_location in
                      let root_snarked_ledger =
                        Ledger.Db.create
                          ?directory_name:config.ledger_db_location ()
                      in
                      Logger.debug config.logger ~module_:__MODULE__
                        ~location:__LOC__
                        !"Reading persistence data from %s"
                        transition_frontier_location ;
                      let%map frontier =
                        Transition_frontier_persistence.deserialize
                          ~directory_name ~logger:config.logger
                          ~trust_system:config.trust_system
                          ~verifier:config.verifier ~root_snarked_ledger
                          ~consensus_local_state:config.consensus_local_state
                      in
                      let persistence =
                        Transition_frontier_persistence.create ~directory_name
                          ~logger:config.logger ~flush_capacity
                          ~max_buffer_capacity:(4 * flush_capacity) ()
                      in
                      (Some persistence, root_snarked_ledger, frontier) )
            in
            let frontier_broadcast_pipe_r, frontier_broadcast_pipe_w =
              Broadcast_pipe.create (Some transition_frontier)
            in
            Option.iter persistence ~f:(fun persistence ->
                Transition_frontier_persistence
                .listen_to_frontier_broadcast_pipe frontier_broadcast_pipe_r
                  persistence
                |> don't_wait_for ) ;
            let%bind net =
              Net.create config.net_config
                ~get_staged_ledger_aux_and_pending_coinbases_at_hash:
                  (fun enveloped_hash ->
                  let hash = Envelope.Incoming.data enveloped_hash in
                  Deferred.return
                  @@
                  let open Option.Let_syntax in
                  let%bind frontier =
                    Broadcast_pipe.Reader.peek frontier_broadcast_pipe_r
                  in
                  Sync_handler
                  .get_staged_ledger_aux_and_pending_coinbases_at_hash
                    ~frontier hash )
                ~answer_sync_ledger_query:(fun query_env ->
                  let open Deferred.Or_error.Let_syntax in
                  let ledger_hash, _ = Envelope.Incoming.data query_env in
                  let%bind frontier =
                    Deferred.return @@ peek_frontier frontier_broadcast_pipe_r
                  in
                  Sync_handler.answer_query ~frontier ledger_hash
                    (Envelope.Incoming.map ~f:Tuple2.get2 query_env)
                    ~logger:config.logger ~trust_system:config.trust_system
                  |> Deferred.map
                     (* begin error string prefix so we can pattern-match *)
                       ~f:
                         (Result.of_option
                            ~error:
                              (Error.createf
                                 !"%s for ledger_hash: %{sexp:Ledger_hash.t}"
                                 refused_answer_query_string ledger_hash)) )
                ~transition_catchup:(fun enveloped_hash ->
                  let open Deferred.Option.Let_syntax in
                  let hash = Envelope.Incoming.data enveloped_hash in
                  let%bind frontier =
                    Deferred.return
                    @@ Broadcast_pipe.Reader.peek frontier_broadcast_pipe_r
                  in
                  Deferred.return
                  @@ Sync_handler.transition_catchup ~frontier hash )
                ~get_ancestry:(fun query_env ->
                  let consensus_state = Envelope.Incoming.data query_env in
                  Deferred.return
                  @@
                  let open Option.Let_syntax in
                  let%bind frontier =
                    Broadcast_pipe.Reader.peek frontier_broadcast_pipe_r
                  in
                  Root_prover.prove ~logger:config.logger ~frontier
                    consensus_state )
            in
            let valid_transitions =
              Transition_router.run ~logger:config.logger
                ~trust_system:config.trust_system ~verifier:config.verifier
                ~network:net ~time_controller:config.time_controller
                ~frontier_broadcast_pipe:
                  (frontier_broadcast_pipe_r, frontier_broadcast_pipe_w)
                ~ledger_db
                ~network_transition_reader:
                  (Strict_pipe.Reader.map external_transitions_reader
                     ~f:(fun (tn, tm) -> (`Transition tn, `Time_received tm)))
                ~proposer_transition_reader
            in
            let ( valid_transitions_for_network
                , valid_transitions_for_api
                , new_blocks ) =
              Strict_pipe.Reader.Fork.three valid_transitions
            in
            let%bind transaction_pool =
              Transaction_pool.load ~logger:config.logger
                ~trust_system:config.trust_system
                ~disk_location:config.transaction_pool_disk_location
                ~incoming_diffs:(Net.transaction_pool_diffs net)
                ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
            in
            don't_wait_for
              (Linear_pipe.iter (Transaction_pool.broadcasts transaction_pool)
                 ~f:(fun x ->
                   Net.broadcast_transaction_pool_diff net x ;
                   Deferred.unit )) ;
            Ivar.fill net_ivar net ;
            don't_wait_for
              (Strict_pipe.Reader.iter_without_pushback
                 valid_transitions_for_network ~f:(fun transition_with_hash ->
                   let hash = With_hash.hash transition_with_hash in
                   let consensus_state =
                     With_hash.data transition_with_hash
                     |> External_transition.Validated.protocol_state
                     |> Protocol_state.consensus_state
                   in
                   let now =
                     let open Block_time in
                     now config.time_controller |> to_span_since_epoch
                     |> Span.to_ms
                   in
                   if
                     Ok ()
                     = Consensus.Hooks.received_at_valid_time
                         ~time_received:now consensus_state
                   then (
                     Logger.trace config.logger ~module_:__MODULE__
                       ~location:__LOC__
                       ~metadata:
                         [ ("state_hash", State_hash.to_yojson hash)
                         ; ( "external_transition"
                           , External_transition.Validated.to_yojson
                               (With_hash.data transition_with_hash) ) ]
                       "broadcasting $state_hash" ;
                     (* remove verified status for network broadcast *)
                     Net.broadcast_state net
                       (External_transition.Validated.forget_validation
                          (With_hash.data transition_with_hash)) )
                   else
                     Logger.warn config.logger ~module_:__MODULE__
                       ~location:__LOC__
                       ~metadata:
                         [ ("state_hash", State_hash.to_yojson hash)
                         ; ( "external_transition"
                           , External_transition.Validated.to_yojson
                               (With_hash.data transition_with_hash) ) ]
                       "refusing to broadcast $state_hash because it is too \
                        late" )) ;
            don't_wait_for
              (Strict_pipe.transfer (Net.states net)
                 external_transitions_writer ~f:ident) ;
            let%bind snark_pool =
              Snark_pool.load ~logger:config.logger
                ~trust_system:config.trust_system
                ~disk_location:config.snark_pool_disk_location
                ~incoming_diffs:(Net.snark_pool_diffs net)
                ~frontier_broadcast_pipe:frontier_broadcast_pipe_r
            in
            let%bind wallets =
              Secrets.Wallets.load ~logger:config.logger
                ~disk_location:config.wallets_disk_location
            in
            don't_wait_for
              (Linear_pipe.iter (Snark_pool.broadcasts snark_pool) ~f:(fun x ->
                   Net.broadcast_snark_pool_diff net x ;
                   Deferred.unit )) ;
            let subscriptions =
              Subscriptions.create ~logger:config.logger
                ~time_controller:config.time_controller ~new_blocks ~wallets
                ~external_transition_database:
                  config.external_transition_database
                ~transition_frontier:frontier_broadcast_pipe_r
            in
            return
              { propose_keypairs=
                  Agent.create
                    ~f:(fun kps ->
                      Keypair.Set.to_list kps
                      |> List.map ~f:(fun kp ->
                             (kp, Public_key.compress kp.Keypair.public_key) )
                      |> Keypair.And_compressed_pk.Set.of_list )
                    config.initial_propose_keypairs
              ; snark_worker_key= config.snark_worker_key
              ; net
              ; verifier= config.verifier
              ; wallets
              ; transaction_pool
              ; snark_pool
              ; transition_frontier= frontier_broadcast_pipe_r
              ; time_controller= config.time_controller
              ; external_transitions_writer=
                  Strict_pipe.Writer.to_linear_pipe external_transitions_writer
              ; validated_transitions= valid_transitions_for_api
              ; logger= config.logger
              ; trust_system= config.trust_system
              ; seen_jobs= Work_selector.State.init
              ; staged_ledger_transition_backup_capacity=
                  config.staged_ledger_transition_backup_capacity
              ; receipt_chain_database= config.receipt_chain_database
              ; snark_work_fee= config.snark_work_fee
              ; proposer_transition_writer
              ; consensus_local_state= config.consensus_local_state
              ; transaction_database= config.transaction_database
              ; external_transition_database=
                  config.external_transition_database
              ; subscriptions } ) )
end

module Intf = Intf
