open Core
open Async
open Pipe_lib
open Mina_base
open Mina_transaction
open Mina_state
open Mina_block

module type CONTEXT = sig
  val logger : Logger.t

  val precomputed_values : Precomputed_values.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t

  val commit_id : string

  val zkapp_cmd_limit : int option ref

  val vrf_poll_interval : Time.Span.t

  val proof_cache_db : Proof_cache_tag.cache_db
end

type Structured_log_events.t += Block_produced
  [@@deriving register_event { msg = "Successfully produced a new block" }]

module Singleton_supervisor : sig
  type ('data, 'a) t

  val create :
    task:(unit Ivar.t -> 'data -> ('a, unit) Interruptible.t) -> ('data, 'a) t

  val cancel : (_, _) t -> unit

  val dispatch : ('data, 'a) t -> 'data -> ('a, unit) Interruptible.t
end = struct
  type ('data, 'a) t =
    { mutable task : (unit Ivar.t * ('a, unit) Interruptible.t) option
    ; f : unit Ivar.t -> 'data -> ('a, unit) Interruptible.t
    }

  let create ~task = { task = None; f = task }

  let cancel t =
    match t.task with
    | Some (ivar, _) ->
        if Ivar.is_full ivar then
          [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
        Ivar.fill ivar () ;
        t.task <- None
    | None ->
        ()

  let dispatch t data =
    cancel t ;
    let ivar = Ivar.create () in
    let interruptible =
      let open Interruptible.Let_syntax in
      t.f ivar data
      >>| fun x ->
      t.task <- None ;
      x
    in
    t.task <- Some (ivar, interruptible) ;
    interruptible
end

let time_to_ms = Fn.compose Block_time.Span.to_ms Block_time.to_span_since_epoch

let time_of_ms = Fn.compose Block_time.of_span_since_epoch Block_time.Span.of_ms

let lift_sync f =
  Interruptible.uninterruptible
    (Deferred.create (fun ivar ->
         if Ivar.is_full ivar then
           [%log' error (Logger.create ())] "Ivar.fill bug is here!" ;
         Ivar.fill ivar (f ()) ) )

module Singleton_scheduler : sig
  type t

  val create : Block_time.Controller.t -> t

  (** If you reschedule when already scheduled, take the min of the two schedulings *)
  val schedule : t -> Block_time.t -> f:(unit -> unit) -> unit
end = struct
  type t =
    { mutable timeout : unit Block_time.Timeout.t option
    ; time_controller : Block_time.Controller.t
    }

  let create time_controller = { time_controller; timeout = None }

  let cancel t =
    match t.timeout with
    | Some timeout ->
        Block_time.Timeout.cancel t.time_controller timeout () ;
        t.timeout <- None
    | None ->
        ()

  let schedule t time ~f =
    let remaining_time =
      Option.map t.timeout ~f:Block_time.Timeout.remaining_time
    in
    cancel t ;
    let span_till_time =
      Block_time.diff time (Block_time.now t.time_controller)
    in
    let wait_span =
      match remaining_time with
      | Some remaining
        when Block_time.Span.(remaining > Block_time.Span.of_ms Int64.zero) ->
          let min a b = if Block_time.Span.(a < b) then a else b in
          min remaining span_till_time
      | None | Some _ ->
          span_till_time
    in
    let timeout =
      Block_time.Timeout.create t.time_controller wait_span ~f:(fun _ ->
          t.timeout <- None ;
          f () )
    in
    t.timeout <- Some timeout
end

let time ~logger ~time_controller label f =
  let open Deferred.Result.Let_syntax in
  let t0 = Block_time.now time_controller in
  let%map x = f () in
  let span = Block_time.diff (Block_time.now time_controller) t0 in
  [%log info]
    ~metadata:
      [ ("time", `Int (Block_time.Span.to_ms span |> Int64.to_int_exn)) ]
    !"%s: $time %!" label ;
  x

let retry ?(max = 3) ~logger ~error_message f =
  let rec go n =
    if n >= max then failwith error_message
    else
      match%bind f () with
      | Error e ->
          [%log error] "%s : $error. Trying again" error_message
            ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ;
          go (n + 1)
      | Ok res ->
          return res
  in
  go 0

let validate_genesis_protocol_state_block ~genesis_state_hash (b, v) =
  Validation.validate_genesis_protocol_state ~genesis_state_hash
    (With_hash.map ~f:Mina_block.header b, v)
  |> Result.map
       ~f:(Fn.flip Validation.with_body (Mina_block.body @@ With_hash.data b))

let log_bootstrap_mode ~logger () =
  [%log info] "Pausing block production while bootstrapping"

let genesis_breadcrumb_creator ~context:(module Context : CONTEXT) prover =
  let open Context in
  let started = ref false in
  let genesis_breadcrumb_ivar = Ivar.create () in
  fun () ->
    if !started then Ivar.read genesis_breadcrumb_ivar
    else (
      started := true ;
      let max_num_retries = 3 in
      let rec go retries =
        [%log info]
          "Generating genesis proof ($attempts_remaining / $max_attempts)"
          ~metadata:
            [ ("attempts_remaining", `Int retries)
            ; ("max_attempts", `Int max_num_retries)
            ] ;
        match%bind
          Prover.create_genesis_block prover
            (Genesis_proof.to_inputs precomputed_values)
        with
        | Ok res ->
            Ivar.fill genesis_breadcrumb_ivar (Ok res) ;
            return (Ok res)
        | Error err ->
            [%log error] "Failed to generate genesis breadcrumb: $error"
              ~metadata:[ ("error", Error_json.error_to_yojson err) ] ;
            if retries > 0 then go (retries - 1)
            else (
              Ivar.fill genesis_breadcrumb_ivar (Error err) ;
              return (Error err) )
      in
      go max_num_retries )

let produce ~genesis_breadcrumb ~context:(module Context : CONTEXT) ~prover
    ~verifier ~trust_system ~frontier_reader ~time_controller ~transition_writer
    ~block_produced_bvar ~net ivar (scheduled_time, block_data, _winner_pubkey)
    =
  let open Context in
  let module Breadcrumb = Transition_frontier.Breadcrumb in
  let open Interruptible.Let_syntax in
  let rejected_blocks_logger =
    Logger.create ~id:Logger.Logger_id.rejected_blocks ()
  in
  match Broadcast_pipe.Reader.peek frontier_reader with
  | None ->
      log_bootstrap_mode ~logger () ;
      Interruptible.return ()
  | Some frontier -> (
      let global_slot =
        Consensus.Data.Block_data.global_slot_since_genesis block_data
      in
      Internal_tracing.with_slot global_slot
      @@ fun () ->
      [%log internal] "Begin_block_production" ;
      let open Transition_frontier.Extensions in
      let transition_registry =
        get_extension
          (Transition_frontier.extensions frontier)
          Transition_registry
      in
      let crumb = Transition_frontier.best_tip frontier in
      let crumb =
        let crumb_global_slot_since_genesis =
          Breadcrumb.protocol_state crumb
          |> Protocol_state.consensus_state
          |> Consensus.Data.Consensus_state.global_slot_since_genesis
        in
        let block_global_slot_since_genesis =
          Consensus.Proof_of_stake.Data.Block_data.global_slot_since_genesis
            block_data
        in
        if
          Mina_numbers.Global_slot_since_genesis.equal
            crumb_global_slot_since_genesis block_global_slot_since_genesis
        then
          (* We received a block for this slot over the network before
             attempting to produce our own. Build upon its parent instead
             of attempting (and failing) to build upon the block itself.
          *)
          Transition_frontier.find_exn frontier (Breadcrumb.parent_hash crumb)
        else crumb
      in
      let start = Block_time.now time_controller in
      [%log info]
        ~metadata:
          [ ("parent_hash", Breadcrumb.parent_hash crumb |> State_hash.to_yojson)
          ; ( "protocol_state"
            , Breadcrumb.protocol_state crumb |> Protocol_state.value_to_yojson
            )
          ]
        "Producing new block with parent $parent_hash%!" ;
      let previous_transition = Breadcrumb.block_with_hash crumb in
      let previous_protocol_state =
        Header.protocol_state
        @@ Mina_block.header (With_hash.data previous_transition)
      in
      let%bind previous_protocol_state_proof =
        if
          Consensus.Data.Consensus_state.is_genesis_state
            (Protocol_state.consensus_state previous_protocol_state)
          && Option.is_none precomputed_values.proof_data
        then (
          match%bind Interruptible.uninterruptible (genesis_breadcrumb ()) with
          | Ok block ->
              let proof = Blockchain_snark.Blockchain.proof block in
              Interruptible.lift (Deferred.return proof) (Deferred.never ())
          | Error err ->
              [%log error]
                "Aborting block production: cannot generate a genesis proof"
                ~metadata:[ ("error", Error_json.error_to_yojson err) ] ;
              Interruptible.lift (Deferred.never ()) (Deferred.return ()) )
        else
          return
            ( Header.protocol_state_proof
            @@ Mina_block.header (With_hash.data previous_transition) )
      in
      [%log internal] "Get_transactions_from_pool" ;
      let%bind () = Interruptible.lift (Deferred.return ()) (Ivar.read ivar) in
      let next_state_opt = None in
      match next_state_opt with
      | None ->
          Interruptible.return ()
      | Some (protocol_state, internal_transition, pending_coinbase_witness) ->
          let diff =
            Internal_transition.staged_ledger_diff internal_transition
          in
          let commands = Staged_ledger_diff.commands diff in
          let transactions_count = List.length commands in
          let protocol_state_hashes = Protocol_state.hashes protocol_state in
          let consensus_state_with_hashes =
            { With_hash.hash = protocol_state_hashes
            ; data = Protocol_state.consensus_state protocol_state
            }
          in
          [%log internal] "@produced_block_state_hash"
            ~metadata:
              [ ( "state_hash"
                , `String
                    (Mina_base.State_hash.to_base58_check
                       protocol_state_hashes.state_hash ) )
              ] ;
          Internal_tracing.with_state_hash protocol_state_hashes.state_hash
          @@ fun () ->
          Debug_assert.debug_assert (fun () ->
              [%test_result: [ `Take | `Keep ]]
                (Consensus.Hooks.select
                   ~context:(module Context)
                   ~existing:
                     (With_hash.map ~f:Mina_block.consensus_state
                        previous_transition )
                   ~candidate:consensus_state_with_hashes )
                ~expect:`Take
                ~message:
                  "newly generated consensus states should be selected over \
                   their parent" ;
              let root_consensus_state_with_hashes =
                Transition_frontier.root frontier
                |> Breadcrumb.consensus_state_with_hashes
              in
              [%test_result: [ `Take | `Keep ]]
                (Consensus.Hooks.select
                   ~context:(module Context)
                   ~existing:root_consensus_state_with_hashes
                   ~candidate:consensus_state_with_hashes )
                ~expect:`Take
                ~message:
                  "newly generated consensus states should be selected over \
                   the tf root" ) ;
          Interruptible.uninterruptible
            (let open Deferred.Let_syntax in
            let emit_breadcrumb () =
              let open Deferred.Result.Let_syntax in
              [%log internal]
                ~metadata:[ ("transactions_count", `Int transactions_count) ]
                "Produce_state_transition_proof" ;
              let%bind protocol_state_proof =
                time ~logger ~time_controller
                  "Protocol_state_proof proving time(ms)" (fun () ->
                    O1trace.thread "dispatch_block_proving" (fun () ->
                        Prover.prove prover ~prev_state:previous_protocol_state
                          ~prev_state_proof:previous_protocol_state_proof
                          ~next_state:protocol_state internal_transition
                          pending_coinbase_witness )
                    |> Deferred.Result.map_error ~f:(fun err ->
                           `Prover_error
                             ( err
                             , ( previous_protocol_state_proof
                               , internal_transition
                               , pending_coinbase_witness ) ) ) )
              in
              let staged_ledger_diff =
                Internal_transition.staged_ledger_diff internal_transition
              in
              let previous_state_hash =
                (Protocol_state.hashes previous_protocol_state).state_hash
              in
              [%log internal] "Produce_chain_transition_proof" ;
              let delta_block_chain_proof =
                Transition_chain_prover.prove
                  ~length:(Mina_numbers.Length.to_int consensus_constants.delta)
                  ~frontier previous_state_hash
                |> Option.value_exn
              in
              [%log internal] "Produce_validated_transition" ;
              let%bind transition =
                let open Result.Let_syntax in
                Validation.wrap
                  { With_hash.hash = protocol_state_hashes
                  ; data =
                      (let body = Body.create staged_ledger_diff in
                       Mina_block.create ~body
                         ~header:
                           (Header.create ~protocol_state ~protocol_state_proof
                              ~delta_block_chain_proof () ) )
                  }
                |> Validation.skip_time_received_validation
                     `This_block_was_not_received_via_gossip
                |> Validation.skip_protocol_versions_validation
                     `This_block_has_valid_protocol_versions
                |> validate_genesis_protocol_state_block
                     ~genesis_state_hash:
                       (Protocol_state.genesis_state_hash
                          ~state_hash:(Some previous_state_hash)
                          previous_protocol_state )
                >>| Validation.skip_proof_validation
                      `This_block_was_generated_internally
                >>| Validation.skip_delta_block_chain_validation
                      `This_block_was_not_received_via_gossip
                >>= Validation.validate_frontier_dependencies
                      ~to_header:Mina_block.header
                      ~context:(module Context)
                      ~root_block:
                        ( Transition_frontier.root frontier
                        |> Breadcrumb.block_with_hash )
                      ~is_block_in_frontier:
                        (Fn.compose Option.is_some
                           (Transition_frontier.find frontier) )
                |> Deferred.return
              in
              let transition_receipt_time = Some (Time.now ()) in
              let%bind breadcrumb =
                time ~logger ~time_controller
                  "Build breadcrumb on produced block" (fun () ->
                    Breadcrumb.build ~proof_cache_db ~logger ~precomputed_values
                      ~verifier ~get_completed_work:(Fn.const None)
                      ~trust_system ~parent:crumb ~transition
                      ~sender:None (* Consider skipping `All here *)
                      ~skip_staged_ledger_verification:`Proofs
                      ~transition_receipt_time () )
                |> Deferred.Result.map_error ~f:(function
                     | `Invalid_staged_ledger_diff e ->
                         `Invalid_staged_ledger_diff (e, staged_ledger_diff)
                     | ( `Fatal_error _
                       | `Invalid_genesis_protocol_state
                       | `Invalid_staged_ledger_hash _
                       | `Not_selected_over_frontier_root
                       | `Parent_missing_from_frontier
                       | `Prover_error _ ) as err ->
                         err )
              in
              let txs =
                Mina_block.transactions ~constraint_constants
                  (Breadcrumb.block breadcrumb)
                |> List.map ~f:Transaction.yojson_summary_with_status
              in
              [%log internal] "@block_metadata"
                ~metadata:
                  [ ( "blockchain_length"
                    , Mina_numbers.Length.to_yojson
                      @@ Mina_block.blockchain_length
                      @@ Breadcrumb.block breadcrumb )
                  ; ("transactions", `List txs)
                  ] ;
              [%str_log info]
                ~metadata:[ ("breadcrumb", Breadcrumb.to_yojson breadcrumb) ]
                Block_produced ;
              (* let uptime service (and any other waiters) know about breadcrumb *)
              Bvar.broadcast block_produced_bvar breadcrumb ;
              Mina_metrics.(Counter.inc_one Block_producer.blocks_produced) ;
              Mina_metrics.Block_producer.(
                Block_production_delay_histogram.observe block_production_delay
                  Time.(
                    Span.to_ms
                    @@ diff (now ())
                    @@ Block_time.to_time_exn scheduled_time)) ;
              [%log internal] "Send_breadcrumb_to_transition_frontier" ;
              let%bind.Async.Deferred () =
                Strict_pipe.Writer.write transition_writer breadcrumb
              in
              let metadata =
                [ ( "state_hash"
                  , State_hash.to_yojson protocol_state_hashes.state_hash )
                ]
              in
              [%log internal] "Wait_for_confirmation" ;
              [%log debug] ~metadata
                "Waiting for block $state_hash to be inserted into frontier" ;
              Deferred.choose
                [ Deferred.choice
                    (Transition_registry.register transition_registry
                       protocol_state_hashes.state_hash )
                    (Fn.const (Ok `Transition_accepted))
                ; Deferred.choice
                    ( Block_time.Timeout.create time_controller
                        (* We allow up to 20 seconds for the transition
                           to make its way from the transition_writer to
                           the frontier.
                           This value is chosen to be reasonably
                           generous. In theory, this should not take
                           terribly long. But long cycles do happen in
                           our system, and with medium curves those long
                           cycles can be substantial.
                        *)
                        (Block_time.Span.of_ms 20000L)
                        ~f:(Fn.const ())
                    |> Block_time.Timeout.to_deferred )
                    (Fn.const (Ok `Timed_out))
                ]
              >>= function
              | `Transition_accepted ->
                  [%log internal] "Transition_accepted" ;
                  [%log info] ~metadata
                    "Generated transition $state_hash was accepted into \
                     transition frontier" ;
                  Deferred.map ~f:Result.return
                    (Mina_networking.broadcast_state net
                       (Breadcrumb.block_with_hash breadcrumb) )
              | `Timed_out ->
                  (* FIXME #3167: this should be fatal, and more
                     importantly, shouldn't happen.
                  *)
                  [%log internal] "Transition_accept_timeout" ;
                  let msg : (_, unit, string, unit) format4 =
                    "Timed out waiting for generated transition $state_hash to \
                     enter transition frontier. Continuing to produce new \
                     blocks anyway. This may mean your CPU is overloaded. \
                     Consider disabling `-run-snark-worker` if it's \
                     configured."
                  in
                  let span =
                    Block_time.diff (Block_time.now time_controller) start
                  in
                  let metadata =
                    [ ( "time"
                      , `Int (Block_time.Span.to_ms span |> Int64.to_int_exn) )
                    ; ( "protocol_state"
                      , Protocol_state.Value.to_yojson protocol_state )
                    ]
                    @ metadata
                  in
                  [%log' debug rejected_blocks_logger] ~metadata msg ;
                  [%log fatal] ~metadata msg ;
                  return ()
            in
            let%bind _ = emit_breadcrumb () in
            Deferred.unit) )

let iteration ~schedule_next_vrf_check ~produce_block_now
    ~schedule_block_production ~next_vrf_check_now
    ~context:(module Context : CONTEXT) ~time_controller ~coinbase_receiver
    ~set_next_producer_timing ~transition_frontier ~epoch_data_for_vrf
    ~ledger_snapshot _i _slot =
  O1trace.thread "block_producer_iteration"
  @@ fun () ->
  let consensus_state =
    Transition_frontier.(
      best_tip transition_frontier |> Breadcrumb.consensus_state)
  in
  let new_global_slot =
    epoch_data_for_vrf.Consensus.Data.Epoch_data_for_vrf.global_slot
  in
  let open Context in
  match failwith "bla" with
  | None -> (
      (*Keep trying until we get some slots*)
      let poll () = schedule_next_vrf_check (Block_time.now time_controller) in
      match failwith "bla" with
      | "Completed" ->
          let epoch_end_time =
            Consensus.Hooks.epoch_end_time ~constants:consensus_constants
              epoch_data_for_vrf.epoch
          in
          set_next_producer_timing (`Check_again epoch_end_time) consensus_state ;
          schedule_next_vrf_check epoch_end_time
      | "at" ->
          let last_slot = new_global_slot (*bug of course*) in
          set_next_producer_timing (`Evaluating_vrf last_slot) consensus_state ;
          poll ()
      | "Start" ->
          set_next_producer_timing (`Evaluating_vrf new_global_slot)
            consensus_state ;
          poll ()
      | _ ->
          Deferred.unit )
  | Some (slot_won : Consensus.Data.Slot_won.t) -> (
      let winning_global_slot = slot_won.global_slot in
      let slot, epoch =
        let t =
          Consensus.Data.Consensus_time.of_global_slot winning_global_slot
            ~constants:consensus_constants
        in
        Consensus.Data.Consensus_time.(slot t, epoch t)
      in
      [%log info] "Block producer won slot $slot in epoch $epoch"
        ~metadata:
          [ ( "slot"
            , Mina_numbers.Global_slot_since_genesis.(
                to_yojson @@ of_uint32 slot) )
          ; ("epoch", Mina_numbers.Length.to_yojson epoch)
          ] ;
      let now = Block_time.now time_controller in
      let curr_global_slot =
        Consensus.Data.Consensus_time.(
          of_time_exn ~constants:consensus_constants now |> to_global_slot)
      in
      let winner_pk = fst slot_won.delegator in
      let data =
        Consensus.Hooks.get_block_data ~slot_won ~ledger_snapshot
          ~coinbase_receiver:!coinbase_receiver
      in
      if
        Mina_numbers.Global_slot_since_hard_fork.(
          curr_global_slot = winning_global_slot)
      then (
        (*produce now*)
        [%log info] "Producing a block now" ;
        set_next_producer_timing
          (`Produce_now (data, winner_pk))
          consensus_state ;
        Mina_metrics.(Counter.inc_one Block_producer.slots_won) ;
        produce_block_now (now, data, winner_pk) )
      else
        match
          Mina_numbers.Global_slot_since_hard_fork.diff winning_global_slot
            curr_global_slot
        with
        | None ->
            [%log warn]
              "Skipping block production for global slot $slot_won because it \
               has passed. Current global slot is $curr_slot"
              ~metadata:
                [ ( "slot_won"
                  , Mina_numbers.Global_slot_since_hard_fork.to_yojson
                      winning_global_slot )
                ; ( "curr_slot"
                  , Mina_numbers.Global_slot_since_hard_fork.to_yojson
                      curr_global_slot )
                ] ;
            next_vrf_check_now ()
        | Some slot_diff ->
            [%log info] "Producing a block in $slots slots"
              ~metadata:
                [ ("slots", Mina_numbers.Global_slot_span.to_yojson slot_diff) ] ;
            let time =
              Consensus.Data.Consensus_time.(
                start_time ~constants:consensus_constants
                  (of_global_slot ~constants:consensus_constants
                     winning_global_slot ))
              |> Block_time.to_span_since_epoch |> Block_time.Span.to_ms
            in
            set_next_producer_timing
              (`Produce (time, data, winner_pk))
              consensus_state ;
            Mina_metrics.(Counter.inc_one Block_producer.slots_won) ;
            let scheduled_time = time_of_ms time in
            schedule_block_production (scheduled_time, data, winner_pk) )

let run ~context:(module Context : CONTEXT) ~prover ~verifier ~trust_system
    ~time_controller ~consensus_local_state ~coinbase_receiver ~frontier_reader
    ~transition_writer ~set_next_producer_timing ~block_produced_bvar ~net =
  let open Context in
  O1trace.sync_thread "produce_blocks" (fun () ->
      let genesis_breadcrumb =
        genesis_breadcrumb_creator ~context:(module Context) prover
      in
      let slot_tx_end =
        Runtime_config.slot_tx_end precomputed_values.runtime_config
      in
      let slot_chain_end =
        Runtime_config.slot_chain_end precomputed_values.runtime_config
      in
      let produce =
        produce ~genesis_breadcrumb
          ~context:(module Context : CONTEXT)
          ~prover ~verifier ~trust_system ~frontier_reader ~time_controller
          ~transition_writer ~block_produced_bvar ~net
      in
      let module Breadcrumb = Transition_frontier.Breadcrumb in
      let production_supervisor = Singleton_supervisor.create ~task:produce in
      let scheduler = Singleton_scheduler.create time_controller in
      let rec check_next_block_timing slot i () =
        (* Begin checking for the ability to produce a block *)
        match Broadcast_pipe.Reader.peek frontier_reader with
        | None ->
            log_bootstrap_mode ~logger () ;
            don't_wait_for
              (let%map () =
                 Broadcast_pipe.Reader.iter_until frontier_reader
                   ~f:(Fn.compose Deferred.return Option.is_some)
               in
               check_next_block_timing slot i () )
        | Some transition_frontier ->
            let consensus_state =
              Transition_frontier.best_tip transition_frontier
              |> Breadcrumb.consensus_state
            in
            let now = Block_time.now time_controller in
            let epoch_data_for_vrf, ledger_snapshot =
              O1trace.sync_thread "get_epoch_data_for_vrf" (fun () ->
                  Consensus.Hooks.get_epoch_data_for_vrf
                    ~constants:consensus_constants (time_to_ms now)
                    consensus_state ~local_state:consensus_local_state ~logger )
            in
            let i' = Mina_numbers.Length.succ epoch_data_for_vrf.epoch in
            let new_global_slot = epoch_data_for_vrf.global_slot in
            let log_if_slot_diff_is_less_than =
              let current_global_slot =
                Consensus.Data.Consensus_time.(
                  to_global_slot
                    (of_time_exn ~constants:consensus_constants
                       (Block_time.now time_controller) ))
              in
              fun ~diff_limit ~every ~message -> function
                | None ->
                    ()
                | Some slot ->
                    let slot_diff =
                      let open Mina_numbers in
                      Option.map ~f:Global_slot_span.to_int
                      @@ Global_slot_since_hard_fork.diff slot
                           current_global_slot
                    in
                    Option.iter slot_diff ~f:(fun slot_diff' ->
                        if slot_diff' <= diff_limit && slot_diff' mod every = 0
                        then
                          [%log info] message
                            ~metadata:[ ("slot_diff", `Int slot_diff') ] )
            in
            log_if_slot_diff_is_less_than ~diff_limit:480 ~every:60
              ~message:
                "Block producer will stop producing blocks after $slot_diff \
                 slots"
              slot_chain_end ;
            log_if_slot_diff_is_less_than ~diff_limit:480 ~every:60
              ~message:
                "Block producer will begin producing only empty blocks after \
                 $slot_diff slots"
              slot_tx_end ;
            let next_vrf_check_now =
              check_next_block_timing new_global_slot i'
            in
            (* TODO: Re-enable this assertion when it doesn't fail dev demos
             *       (see #5354)
             * assert (
                   Consensus.Hooks.required_local_state_sync
                    ~constants:consensus_constants ~consensus_state
                    ~local_state:consensus_local_state
                   = None ) ; *)
            let produce_block_now triple =
              ignore
                ( Interruptible.finally
                    (Singleton_supervisor.dispatch production_supervisor triple)
                    ~f:next_vrf_check_now
                  : (_, _) Interruptible.t )
            in
            don't_wait_for
              ( iteration
                  ~schedule_next_vrf_check:
                    (Fn.compose Deferred.return
                       (Singleton_scheduler.schedule scheduler
                          ~f:next_vrf_check_now ) )
                  ~produce_block_now:
                    (Fn.compose Deferred.return produce_block_now)
                  ~schedule_block_production:(fun (time, data, winner) ->
                    Singleton_scheduler.schedule scheduler time ~f:(fun () ->
                        produce_block_now (time, data, winner) ) ;
                    Deferred.unit )
                  ~next_vrf_check_now:
                    (Fn.compose Deferred.return next_vrf_check_now)
                  ~context:(module Context)
                  ~time_controller ~coinbase_receiver ~set_next_producer_timing
                  ~transition_frontier ~epoch_data_for_vrf ~ledger_snapshot i
                  slot
                : unit Deferred.t )
      in
      let start () =
        check_next_block_timing Mina_numbers.Global_slot_since_hard_fork.zero
          Mina_numbers.Length.zero ()
      in
      let genesis_state_timestamp =
        consensus_constants.genesis_state_timestamp
      in
      (* if the producer starts before genesis, sleep until genesis *)
      let now = Block_time.now time_controller in
      if Block_time.( >= ) now genesis_state_timestamp then start ()
      else
        let time_till_genesis = Block_time.diff genesis_state_timestamp now in
        [%log warn]
          ~metadata:
            [ ( "time_till_genesis"
              , `Int
                  (Int64.to_int_exn (Block_time.Span.to_ms time_till_genesis))
              )
            ]
          "Node started before genesis: waiting $time_till_genesis \
           milliseconds before starting block producer" ;
        ignore
          ( Block_time.Timeout.create time_controller time_till_genesis
              ~f:(fun _ -> start ())
            : unit Block_time.Timeout.t ) )
