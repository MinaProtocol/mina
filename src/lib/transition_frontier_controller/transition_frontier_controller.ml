open Core_kernel
open Async_kernel
open Pipe_lib
open Mina_block
open Mina_base
module Bit_catchup = Bit_catchup

module type CONTEXT = Context.MINI_CONTEXT

let run_with_normal_or_super_catchup ~context:(module Context : CONTEXT)
    ~trust_system ~verifier ~network ~time_controller ~get_completed_work
    ~(collected_transitions : Transition_frontier.Gossip.element list) ~frontier
    ~network_transition_reader ~producer_transition_reader ~clear_reader
    ~verified_transition_writer =
  let open Context in
  let valid_transition_pipe_capacity = 50 in
  let start_time = Time.now () in
  let f_drop_head name head gd_map =
    let valid_cbs = Transition_frontier.Gossip.valid_cbs gd_map in
    let state_hash =
      match head with
      | `Block b ->
          State_hash.With_state_hashes.state_hash @@ Validation.block_with_hash
          @@ Cache_lib.Cached.peek b
      | `Header h ->
          State_hash.With_state_hashes.state_hash
          @@ Validation.header_with_hash h
    in
    Mina_block.handle_dropped_transition ~valid_cbs ~logger ~pipe_name:name
      state_hash
  in
  let valid_transition_reader, valid_transition_writer =
    let name = "valid transitions" in
    Strict_pipe.create ~name
      (Buffered
         ( `Capacity valid_transition_pipe_capacity
         , `Overflow
             (Drop_head
                (fun (head, `Gossip_map gd_map) ->
                  Mina_metrics.(
                    Counter.inc_one
                      Pipe.Drop_on_overflow
                      .transition_frontier_valid_transitions) ;
                  f_drop_head name head gd_map ) ) ) )
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
                (fun (head, `Gossip_map gd_map) ->
                  Mina_metrics.(
                    Counter.inc_one
                      Pipe.Drop_on_overflow
                      .transition_frontier_primary_transitions) ;
                  f_drop_head name head gd_map ) ) ) )
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
  List.iter collected_transitions ~f:(fun (t, `Gossip_map gd_map) ->
      Option.iter (String.Map.min_elt gd_map)
        ~f:(fun (_, Transition_frontier.Gossip.{ received_at; sender; _ }) ->
          let cached =
            match t with
            | `Block data ->
                let env =
                  { Network_peer.Envelope.Incoming.data; received_at; sender }
                in
                (* since the cache was just built, it's safe to assume
                 * registering these will not fail, so long as there
                 * are no duplicates in the list *)
                `Block
                  ( Transition_handler.Unprocessed_transition_cache.register_exn
                      unprocessed_transition_cache env
                  |> Cache_lib.Cached.transform ~f:(const data) )
            | `Header h ->
                `Header h
          in
          Strict_pipe.Writer.write primary_transition_writer
            (cached, `Gossip_map gd_map) ) ) ;
  let initial_state_hashes =
    List.map collected_transitions ~f:(fun (b_or_h, _) ->
        Transition_frontier.Gossip.header_with_hash b_or_h
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
    ~f:(Strict_pipe.Writer.write primary_transition_writer)
  |> don't_wait_for ;
  let clean_up_catchup_scheduler = Ivar.create () in
  Transition_handler.Processor.run
    ~context:(module Context)
    ~network ~time_controller ~trust_system ~verifier ~frontier
    ~get_completed_work ~primary_transition_reader ~producer_transition_reader
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

  Strict_pipe.Reader.iter_without_pushback processed_transition_reader
    ~f:(Strict_pipe.Writer.write verified_transition_writer)
  |> don't_wait_for

let run ~on_bitswap_update_ref ~frontier =
  match Transition_frontier.catchup_state frontier with
  | Full _ | Hash _ ->
      run_with_normal_or_super_catchup ~frontier
  | Bit _ ->
      Bit_catchup.run ~on_bitswap_update_ref ~frontier
