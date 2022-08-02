module Schema = Graphql_wrapper.Make(Graphql_async.Schema)
open Schema
open Core_kernel

let nn_catchup_status a x =
  Graphql_basic_scalars.Reflection.reflect
    (fun o ->
      Option.map o
        ~f:
        (List.map ~f:(function
             | ( Transition_frontier.Full_catchup_tree.Node.State.Enum
                   .Finished
               , _ ) ->
                "finished"
             | Failed, _ ->
                "failed"
             | To_download, _ ->
                "to_download"
             | To_initial_validate, _ ->
                "to_initial_validate"
             | To_verify, _ ->
                "to_verify"
             | Wait_for_parent, _ ->
                "wait_for_parent"
             | To_build_breadcrumb, _ ->
                "to_build_breadcrumb"
             | Root, _ ->
                "root" ) ) )
    ~typ:(list (non_null string))
    a x

open Graphql_basic_scalars.Shorthand

let rpc_pair () : (_, Perf_histograms.Report.t option Types.Status.Rpc_timings.Rpc_pair.t option) typ =
  let h = id ~typ:(Perf_histograms_unix.Graphql_objects.histogram ()) in
  obj "RpcPair" ~fields:(fun _ ->
      List.rev @@ Types.Status.Rpc_timings.Rpc_pair.Fields.fold ~init:[] ~dispatch:h ~impl:h )

let rpc_timings () : (_, Types.Status.Rpc_timings.t option) typ =
  let fd = id ~typ:(non_null @@ rpc_pair ()) in
  obj "RpcTimings" ~fields:(fun _ ->
      List.rev
      @@ Types.Status.Rpc_timings.Fields.fold ~init:[] ~get_staged_ledger_aux:fd
           ~answer_sync_ledger_query:fd ~get_ancestry:fd
           ~get_transition_chain_proof:fd ~get_transition_chain:fd )

let histograms () : (_, Types.Status.Histograms.t option) typ =
  let h = id ~typ:(Perf_histograms_unix.Graphql_objects.histogram ()) in
  obj "Histograms" ~fields:(fun _ ->
      List.rev
      @@ Types.Status.Histograms.Fields.fold ~init:[]
           ~rpc_timings:(id ~typ:(non_null @@ rpc_timings ()))
           ~external_transition_latency:h
           ~accepted_transition_local_latency:h
           ~accepted_transition_remote_latency:h
           ~snark_worker_transition_time:h ~snark_worker_merge_time:h )

let metrics () : (_, Types.Status.Metrics.t option) typ =
  obj "Metrics" ~fields:(fun _ ->
      List.rev
      @@ Types.Status.Metrics.Fields.fold ~init:[]
           ~block_production_delay:nn_int_list
           ~transaction_pool_diff_received:nn_int
           ~transaction_pool_diff_broadcasted:nn_int
           ~transactions_added_to_pool:nn_int ~transaction_pool_size:nn_int )

  (* let block_producer_timing : *)
  (*     (_, Daemon_rpcs.Types.Status.Next_producer_timing.t option) typ = *)
  (*   obj "BlockProducerTimings" ~fields:(fun _ -> *)
  (*       let of_time ~consensus_constants = *)
  (*         Consensus.Data.Consensus_time.of_time_exn *)
  (*           ~constants:consensus_constants *)
  (*       in *)
  (*       [ field "times" *)
  (*           ~typ:(non_null @@ list @@ non_null consensus_time) *)
  (*           ~doc:"Next block production time" *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun { ctx = coda; _ } *)
  (*                         { Daemon_rpcs.Types.Status.Next_producer_timing.timing *)
  (*                         ; _ *)
  (*                         } -> *)
  (*             let consensus_constants = *)
  (*               (Mina_lib.config coda).precomputed_values.consensus_constants *)
  (*             in *)
  (*             match timing with *)
  (*             | Daemon_rpcs.Types.Status.Next_producer_timing.Check_again _ -> *)
  (*                 [] *)
  (*             | Evaluating_vrf _last_checked_slot -> *)
  (*                 [] *)
  (*             | Produce info -> *)
  (*                 [ of_time info.time ~consensus_constants ] *)
  (*             | Produce_now info -> *)
  (*                 [ of_time ~consensus_constants info.time ] ) *)
  (*       ; field "globalSlotSinceGenesis" *)
  (*           ~typ:(non_null @@ list @@ non_null uint32) *)
  (*           ~doc:"Next block production global-slot-since-genesis " *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun _ *)
  (*                         { Daemon_rpcs.Types.Status.Next_producer_timing.timing *)
  (*                         ; _ *)
  (*                         } -> *)
  (*             match timing with *)
  (*             | Daemon_rpcs.Types.Status.Next_producer_timing.Check_again _ -> *)
  (*                 [] *)
  (*             | Evaluating_vrf _last_checked_slot -> *)
  (*                 [] *)
  (*             | Produce info -> *)
  (*                 [ info.for_slot.global_slot_since_genesis ] *)
  (*             | Produce_now info -> *)
  (*                 [ info.for_slot.global_slot_since_genesis ] ) *)
  (*       ; field "generatedFromConsensusAt" *)
  (*           ~typ:(non_null consensus_time_with_global_slot_since_genesis) *)
  (*           ~doc: *)
  (*             "Consensus time of the block that was used to determine the next \ *)
  (*              block production time" *)
  (*           ~args:Arg.[] *)
  (*           ~resolve:(fun { ctx = coda; _ } *)
  (*                         { Daemon_rpcs.Types.Status.Next_producer_timing *)
  (*                           .generated_from_consensus_at = *)
  (*                             { slot; global_slot_since_genesis } *)
  (*                         ; _ *)
  (*                         } -> *)
  (*             let consensus_constants = *)
  (*               (Mina_lib.config coda).precomputed_values.consensus_constants *)
  (*             in *)
  (*             ( Consensus.Data.Consensus_time.of_global_slot *)
  (*                 ~constants:consensus_constants slot *)
  (*             , global_slot_since_genesis ) ) *)
  (*       ] ) *)

(* let daemon_status () : (_, Daemon_rpcs.Types.Status.t option) typ = *)
(*   obj "DaemonStatus" ~fields:(fun _ -> *)
(*       let open Graphql_basic_scalars.Shorthand in *)
(*       List.rev *)
(*       @@ Daemon_rpcs.Types.Status.Fields.fold ~init:[] ~num_accounts:int *)
(*            ~catchup_status:nn_catchup_status ~chain_id:nn_string *)
(*            ~next_block_production:(id ~typ:block_producer_timing) *)
(*            ~blockchain_length:int ~uptime_secs:nn_int *)
(*            ~ledger_merkle_root:string ~state_hash:string *)
(*            ~commit_id:nn_string ~conf_dir:nn_string *)
(*            ~peers:(id ~typ:(non_null (list (non_null peer)))) *)
(*            ~user_commands_sent:nn_int ~snark_worker:string *)
(*            ~snark_work_fee:nn_int *)
(*            ~sync_status:(id ~typ:(non_null sync_status)) *)
(*            ~block_production_keys: *)
(*            (id ~typ:(non_null @@ list (non_null Schema.string))) *)
(*            ~coinbase_receiver:(id ~typ:Schema.string) *)
(*            ~histograms:(id ~typ:histograms) *)
(*            ~consensus_time_best_tip:(id ~typ:consensus_time) *)
(*            ~global_slot_since_genesis_best_tip:int *)
(*            ~consensus_time_now:(id ~typ:Schema.(non_null consensus_time)) *)
(*            ~consensus_mechanism:nn_string *)
(*            ~addrs_and_ports:(id ~typ:(non_null addrs_and_ports)) *)
(*            ~consensus_configuration: *)
(*            (id ~typ:(non_null consensus_configuration)) *)
(*            ~highest_block_length_received:nn_int *)
(*            ~highest_unvalidated_block_length_received:nn_int *)
(*            ~metrics:(id ~typ:(non_null metrics)) ) *)
