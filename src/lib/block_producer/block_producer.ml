open Core
open Async
open Pipe_lib

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

let run ~context:(module Context : CONTEXT) ~time_controller
    ~consensus_local_state ~coinbase_receiver ~frontier_reader
    ~set_next_producer_timing =
  let open Context in
  O1trace.sync_thread "produce_blocks" (fun () ->
      let slot_tx_end =
        Runtime_config.slot_tx_end precomputed_values.runtime_config
      in
      let slot_chain_end =
        Runtime_config.slot_chain_end precomputed_values.runtime_config
      in
      let produce _ _ = Interruptible.return () in
      let module Breadcrumb = Transition_frontier.Breadcrumb in
      let production_supervisor = Singleton_supervisor.create ~task:produce in
      let scheduler = Singleton_scheduler.create time_controller in
      let rec check_next_block_timing slot i () =
        (* Begin checking for the ability to produce a block *)
        match Broadcast_pipe.Reader.peek frontier_reader with
        | None ->
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
