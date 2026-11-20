open Core_kernel
open Async_kernel
open Pipe_lib
open Mina_block

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val proof_cache_db : Proof_cache_tag.cache_db

  val signature_kind : Mina_signature_kind.t
end

let run ~context:(module Context : CONTEXT) ~trust_system ~verifier ~network
    ~time_controller ~collected_transitions ~frontier ~get_completed_work
    ~network_transition_reader ~producer_transition_reader ~stop ~drained
    ~cache_exceptions ?transaction_pool_proxy =
  let open Context in
  let valid_transition_pipe_capacity = 50 in
  let start_time = Time.now () in
  let block_registry =
    Transition_handler.Block_registry.create ~logger ~cache_exceptions
  in
  let in_flight = Otp_lib.In_flight.create () in
  let f_drop_head name head =
    let hashes =
      match head with
      | `Block b ->
          With_hash.hash @@ Validation.block_with_hash
          @@ Network_peer.Envelope.Incoming.data @@ Cache_lib.Cached.peek b
      | `Header h ->
          With_hash.hash @@ Validation.header_with_hash
          @@ Network_peer.Envelope.Incoming.data h
    in
    (* Dropping a transition for want of room says nothing about the peer that
       sent it, so it is ignored rather than rejected. *)
    Mina_block.handle_dropped_transition hashes ~pipe_name:name ~logger ;
    match head with
    | `Block b ->
        Transition_handler.Block_registry.finish block_registry b `Ignored
    | `Header _ ->
        Transition_handler.Block_registry.finish_header block_registry
          (Mina_base.State_hash.State_hashes.state_hash hashes)
          `Ignored
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
                (fun head ->
                  Mina_metrics.(
                    Counter.inc_one
                      Pipe.Drop_on_overflow
                      .transition_frontier_primary_transitions) ;
                  f_drop_head name head ) ) ) )
  in
  let processed_transition_reader, processed_transition_writer =
    Strict_pipe.create ~name:"processed transitions"
      (Buffered (`Capacity 30, `Overflow Crash))
  in
  let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
    Strict_pipe.create ~name:"catchup breadcrumbs"
      (Buffered (`Capacity 30, `Overflow Crash))
  in
  List.iter collected_transitions ~f:(fun (t, vc) ->
      let b_or_h =
        match Network_peer.Envelope.Incoming.data t with
        | `Block b ->
            (* since the cache was just built, it's safe to assume
             * registering these will not fail, so long as there
             * are no duplicates in the list *)
            `Block
              (Transition_handler.Block_registry.register_exn block_registry
                 (Network_peer.Envelope.Incoming.map ~f:(const b) t)
                 ~valid_cb:vc )
        | `Header h ->
            let header = Network_peer.Envelope.Incoming.map ~f:(const h) t in
            Transition_handler.Block_registry.register_header block_registry
              header ~valid_cb:vc ;
            `Header header
      in
      Strict_pipe.Writer.write primary_transition_writer b_or_h ) ;
  let initial_state_hashes =
    List.map collected_transitions ~f:(fun (envelope, _) ->
        Network_peer.Envelope.Incoming.data envelope
        |> Bootstrap_controller.Transition_cache.header_with_hash
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
  let dispatcher =
    Transition_handler.Block_dispatcher.create
      ~on_validated:(Strict_pipe.Writer.write primary_transition_writer)
      ~on_dropped:(function
      | `Validated (`Block b) ->
          Transition_handler.Block_registry.finish block_registry b `Ignored
      | `Validated (`Header h) ->
          Transition_handler.Block_registry.finish_header block_registry
            ( Network_peer.Envelope.Incoming.data h
            |> Validation.header_with_hash
            |> Mina_base.State_hash.With_state_hashes.state_hash )
            `Ignored
      | `Catchup_job (_, forest) ->
          List.iter forest
            ~f:
              (Mina_stdlib.Rose_tree.iter ~f:(fun b ->
                   Transition_handler.Block_registry.finish block_registry b
                     `Ignored ) ) )
  in
  let validate_transition =
    Transition_handler.Validator.create_handler
      ~context:(module Context)
      ~trust_system ~time_controller ~frontier
      ~on_valid:(fun transition ->
        Transition_handler.Block_dispatcher.submit dispatcher
          (Validated transition) )
      ~block_registry
  in
  O1trace.background_thread "validate_blocks_against_frontier" (fun () ->
      Pipe_lib.Choosable_synchronous_pipe.iter network_transition_reader
        ~f:validate_transition ) ;
  let catchup_scheduler =
    Transition_handler.Catchup_scheduler.create ~logger ~precomputed_values
      ~block_registry ~in_flight ~verifier ~trust_system ~frontier
      ~time_controller
      ~on_catchup_job:(fun job ->
        Transition_handler.Block_dispatcher.submit dispatcher (Catchup_job job)
        )
      ~catchup_breadcrumbs_writer
  in
  let process_message =
    Transition_handler.Processor.create_handler
      ~context:(module Context)
      ~time_controller ~trust_system ~verifier ~frontier ~get_completed_work
      ~block_registry ~catchup_scheduler ~processed_transition_writer
      ?transaction_pool_proxy ()
  in
  let processing =
    O1trace.thread "process_blocks" (fun () ->
        Strict_pipe.Reader.Merge.iter
          (Transition_handler.Processor.inputs ~primary_transition_reader
             ~producer_transition_reader ~catchup_breadcrumbs_reader )
          ~f:(fun message ->
            Otp_lib.In_flight.run in_flight (fun () -> process_message message) ) )
  in
  O1trace.background_thread "perform_super_catchup" (fun () ->
      Deferred.map
        (Ledger_catchup.create_job_handler
           ~context:(module Context)
           ~trust_system ~verifier ~network ~frontier
           ~catchup_breadcrumbs_writer ~block_registry ~in_flight
           ~schedule:(fun resume ->
             Transition_handler.Block_dispatcher.submit dispatcher
               (Resume_catchup resume) ) )
        ~f:(fun process ->
          Transition_handler.Block_dispatcher.submit dispatcher
            (Catchup_ready process) ) ) ;
  (* Stopping drains the controller: it takes no new work, waits for the work
     already under way, and gives every block it still holds an outcome.
     Whoever stops it must already have killed the producer pipe, and closes
     the frontier only once it has drained. *)
  upon stop (fun () ->
      let open Strict_pipe.Writer in
      Transition_handler.Block_dispatcher.clear dispatcher ;
      (* Stop the scheduler's builder before closing the pipe it hands
         breadcrumbs on through. *)
      Transition_handler.Catchup_scheduler.clean_up catchup_scheduler ;
      kill primary_transition_writer ;
      kill catchup_breadcrumbs_writer ;
      upon
        (let%bind () = processing in
         (* The processor's last messages may have left blocks with the
            scheduler. *)
         Transition_handler.Catchup_scheduler.clean_up catchup_scheduler ;
         Otp_lib.In_flight.idle in_flight )
        (fun () ->
          Transition_handler.Block_registry.finish_outstanding block_registry ;
          kill processed_transition_writer ;
          Ivar.fill drained () ) ) ;
  processed_transition_reader

let%test_module "Transition_frontier_controller" =
  ( module struct
    open Async
    open Network_peer

    let max_frontier_length = 10

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let constraint_constants = precomputed_values.constraint_constants

    let verifier =
      Thread_safe.block_on_async_exn (fun () ->
          Verifier.For_tests.default ~constraint_constants ~logger
            ~proof_level:precomputed_values.proof_level () )

    let ledger_sync_config =
      Syncable_ledger.create_config
        ~compile_config:Mina_compile_config.For_unit_tests.t
        ~max_subtree_depth:None ~default_subtree_depth:None ()

    module Context = struct
      let logger = logger

      let precomputed_values = precomputed_values

      let constraint_constants = constraint_constants

      let consensus_constants = precomputed_values.consensus_constants

      let proof_cache_db = Proof_cache_tag.For_tests.create_db ()

      let signature_kind = Mina_signature_kind.Testnet
    end

    type answer = [ `Accept | `Reject | `Ignore | `Expired ]
    [@@deriving compare, sexp]

    let%test_unit "Stopping drains the controller and answers what it holds" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~verifier ~max_frontier_length
            ~ledger_sync_config
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:(max_frontier_length / 2)
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [ my_net; peer_net ] = network.peer_networks in
          let incoming breadcrumb =
            Envelope.Incoming.local
              ( Transition_frontier.Breadcrumb.validated_transition breadcrumb
              |> Mina_block.Validated.remember
              |> Validation.reset_frontier_dependencies_validation
              |> Validation.reset_staged_ledger_diff_validation )
          in
          let best_tip = Transition_frontier.best_tip peer_net.state.frontier in
          (* A block and a header whose parents this node doesn't have, so the
             controller holds them while it catches up. The header is of
             another block, so that finishing the block can't answer it. *)
          let block = incoming best_tip in
          let header =
            Envelope.Incoming.map ~f:Validation.to_header
              (incoming
                 (Option.value_exn
                    (Transition_frontier.find peer_net.state.frontier
                       (Transition_frontier.Breadcrumb.parent_hash best_tip) ) ) )
          in
          let callback () =
            let valid_cb =
              Mina_net2.Validation_callback.create_without_expiration ()
            in
            let answers = ref [] in
            Mina_net2.Validation_callback.set_on_resolve valid_cb (fun answer ->
                answers := answer :: !answers ) ;
            (valid_cb, answers)
          in
          let block_cb, block_answers = callback () in
          let header_cb, header_answers = callback () in
          let producer_transition_reader, producer_transition_writer =
            Strict_pipe.create ~name:__LOC__ Synchronous
          in
          let network_transition_reader, _network_transition_writer =
            Choosable_synchronous_pipe.create ()
          in
          let stop = Ivar.create () in
          let drained = Ivar.create () in
          let processed_transition_reader =
            run
              ~context:(module Context)
              ~trust_system:(Trust_system.null ()) ~verifier
              ~network:my_net.network
              ~time_controller:(Block_time.Controller.basic ~logger)
              ~collected_transitions:
                [ ( Envelope.Incoming.map block ~f:(fun b -> `Block b)
                  , Some block_cb )
                ; ( Envelope.Incoming.map header ~f:(fun h -> `Header h)
                  , Some header_cb )
                ]
              ~frontier:my_net.state.frontier
              ~get_completed_work:(Fn.const None) ~network_transition_reader
              ~producer_transition_reader ~stop:(Ivar.read stop) ~drained
              ~cache_exceptions:true ?transaction_pool_proxy:None
          in
          Thread_safe.block_on_async_exn (fun () ->
              let%bind () = Scheduler.yield_until_no_jobs_remain () in
              Strict_pipe.Writer.kill producer_transition_writer ;
              Ivar.fill stop () ;
              match%bind
                with_timeout (Time.Span.of_sec 30.) (Ivar.read drained)
              with
              | `Timeout ->
                  failwith "the controller did not drain"
              | `Result () ->
                  [%test_eq: answer list * answer list]
                    (!block_answers, !header_answers)
                    ([ `Ignore ], [ `Ignore ]) ;
                  Strict_pipe.Reader.iter processed_transition_reader
                    ~f:(fun _ -> failwith "a block was passed on") ) )
  end )
