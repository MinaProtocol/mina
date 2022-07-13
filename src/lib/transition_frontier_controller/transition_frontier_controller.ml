open Core_kernel
open Async_kernel
open Pipe_lib
open Mina_block

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

let run_with_normal_or_super_catchup ~context:(module Context : CONTEXT)
    ~trust_system ~verifier ~network ~time_controller ~collected_transitions
    ~frontier ~network_transition_reader ~producer_transition_reader
    ~clear_reader ~verified_transition_writer =
  let open Context in
  let valid_transition_pipe_capacity = 50 in
  let start_time = Time.now () in
  let f_drop_head name head valid_cb =
    let block : Mina_block.initial_valid_block =
      Network_peer.Envelope.Incoming.data @@ Cache_lib.Cached.peek head
    in
    Mina_block.handle_dropped_transition
      (Validation.block_with_hash block |> With_hash.hash)
      ?valid_cb ~pipe_name:name ~logger
  in
  let valid_transition_reader, valid_transition_writer =
    let name = "valid transitions" in
    Strict_pipe.create ~name
      (Buffered
         ( `Capacity valid_transition_pipe_capacity
         , `Overflow
             (Drop_head
                (fun (`Block head, `Valid_cb vc) ->
                  Mina_metrics.(
                    Counter.inc_one
                      Pipe.Drop_on_overflow
                      .transition_frontier_valid_transitions) ;
                  f_drop_head name head vc ) ) ) )
  in
  let primary_transition_pipe_capacity =
    valid_transition_pipe_capacity + List.length collected_transitions
  in
  (* Ok to drop on overflow- catchup will be triggered if required*)
  let primary_transition_reader, primary_transition_writer =
    let name = "primary transitions" in
    Strict_pipe.create ~name
      (Buffered
         ( `Capacity primary_transition_pipe_capacity
         , `Overflow
             (Drop_head
                (fun (`Block head, `Valid_cb vc) ->
                  Mina_metrics.(
                    Counter.inc_one
                      Pipe.Drop_on_overflow
                      .transition_frontier_primary_transitions) ;
                  f_drop_head name head vc ) ) ) )
  in
  let processed_transition_reader, processed_transition_writer =
    Strict_pipe.create ~name:"processed transitions"
      (Buffered (`Capacity 30, `Overflow Crash))
  in
  let catchup_job_reader, catchup_job_writer =
    Strict_pipe.create ~name:"catchup jobs"
      (Buffered (`Capacity 30, `Overflow Crash))
  in
  let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
    Strict_pipe.create ~name:"catchup breadcrumbs"
      (Buffered (`Capacity 30, `Overflow Crash))
  in
  let unprocessed_transition_cache =
    Transition_handler.Unprocessed_transition_cache.create ~logger
  in
  let collected_transitions =
    List.filter_map collected_transitions ~f:(fun (x, vc) ->
        let open Network_peer.Envelope.Incoming in
        match data x with
        | Bootstrap_controller.Transition_cache.Block b ->
            Some (map x ~f:(const b), vc)
        | _ ->
            (* TODO: handle headers too *)
            None )
  in
  List.iter collected_transitions ~f:(fun (t, vc) ->
      (* since the cache was just built, it's safe to assume
       * registering these will not fail, so long as there
       * are no duplicates in the list *)
      let block_cached =
        Transition_handler.Unprocessed_transition_cache.register_exn
          unprocessed_transition_cache t
      in
      Strict_pipe.Writer.write primary_transition_writer
        (`Block block_cached, `Valid_cb vc) ) ;
  let initial_state_hashes =
    List.map collected_transitions ~f:(fun (envelope, _) ->
        Network_peer.Envelope.Incoming.data envelope
        |> Validation.block_with_hash
        |> Mina_base.State_hash.With_state_hashes.state_hash )
    |> Mina_base.State_hash.Set.of_list
  in
  let extensions = Transition_frontier.extensions frontier in
  don't_wait_for
  @@ Pipe_lib.Broadcast_pipe.Reader.iter_until
       (Transition_frontier.Extensions.get_view_pipe extensions New_breadcrumbs)
       ~f:(fun new_breadcrumbs ->
         let open Mina_base.State_hash in
         let new_state_hashes =
           List.map new_breadcrumbs ~f:Transition_frontier.Breadcrumb.state_hash
           |> Set.of_list
         in
         if Set.is_empty @@ Set.inter initial_state_hashes new_state_hashes then
           Deferred.return false
         else (
           Mina_metrics.(
             Gauge.set Catchup.initial_catchup_time
               Time.(Span.to_min @@ diff (now ()) start_time)) ;
           Deferred.return true ) ) ;
  Transition_handler.Validator.run
    ~context:(module Context)
    ~trust_system ~time_controller ~frontier
    ~transition_reader:network_transition_reader ~valid_transition_writer
    ~unprocessed_transition_cache ;
  Strict_pipe.Reader.iter_without_pushback valid_transition_reader
    ~f:(fun (`Block b, `Valid_cb vc) ->
      Strict_pipe.Writer.write primary_transition_writer (`Block b, `Valid_cb vc) )
  |> don't_wait_for ;
  let clean_up_catchup_scheduler = Ivar.create () in
  Transition_handler.Processor.run
    ~context:(module Context)
    ~time_controller ~trust_system ~verifier ~frontier
    ~primary_transition_reader ~producer_transition_reader
    ~clean_up_catchup_scheduler ~catchup_job_writer ~catchup_breadcrumbs_reader
    ~catchup_breadcrumbs_writer ~processed_transition_writer ;
  Ledger_catchup.run
    ~context:(module Context)
    ~trust_system ~verifier ~network ~frontier ~catchup_job_reader
    ~catchup_breadcrumbs_writer ~unprocessed_transition_cache ;
  Strict_pipe.Reader.iter_without_pushback clear_reader ~f:(fun _ ->
      let open Strict_pipe.Writer in
      kill valid_transition_writer ;
      kill primary_transition_writer ;
      kill processed_transition_writer ;
      kill catchup_job_writer ;
      kill catchup_breadcrumbs_writer ;
      if Ivar.is_full clean_up_catchup_scheduler then
        [%log error] "Ivar.fill bug is here!" ;
      Ivar.fill clean_up_catchup_scheduler () )
  |> don't_wait_for ;
  Strict_pipe.Reader.iter processed_transition_reader
    ~f:
      (Fn.compose Deferred.return
         (Strict_pipe.Writer.write verified_transition_writer) )
  |> don't_wait_for

let run ~context:(module Context : CONTEXT) ~trust_system ~verifier ~network
    ~time_controller ~collected_transitions ~frontier ~network_transition_reader
    ~producer_transition_reader ~clear_reader ~verified_transition_writer =
  match Transition_frontier.catchup_state frontier with
  | Hash _ ->
      run_with_normal_or_super_catchup
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller ~collected_transitions
        ~frontier ~network_transition_reader ~producer_transition_reader
        ~clear_reader ~verified_transition_writer
  | Full _ ->
      run_with_normal_or_super_catchup
        ~context:(module Context)
        ~trust_system ~verifier ~network ~time_controller ~collected_transitions
        ~frontier ~network_transition_reader ~producer_transition_reader
        ~clear_reader ~verified_transition_writer
(* TODO add case for bit catchup *)
