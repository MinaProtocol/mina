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
    ~ledger_snapshot _i _slot =
  let open Context in
  match failwith "dequeue from vrf evaluation queue" with
  | None ->
      (*Keep trying until we get some slots*)
      schedule_next_vrf_check (Block_time.now time_controller)
  | Some (slot_won : Consensus.Data.Slot_won.t) -> (
      let winning_global_slot = slot_won.global_slot in
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
      then (*produce now*)
        produce_block_now (now, data, winner_pk)
      else
        match
          Mina_numbers.Global_slot_since_hard_fork.diff winning_global_slot
            curr_global_slot
        with
        | None ->
            next_vrf_check_now ()
        | Some _slot_diff ->
            let time =
              Consensus.Data.Consensus_time.(
                start_time ~constants:consensus_constants
                  (of_global_slot ~constants:consensus_constants
                     winning_global_slot ))
              |> Block_time.to_span_since_epoch |> Block_time.Span.to_ms
            in
            let scheduled_time = time_of_ms time in
            schedule_block_production (scheduled_time, data, winner_pk) )

let run ~context:(module Context : CONTEXT) ~time_controller
    ~consensus_local_state ~coinbase_receiver ~frontier_reader =
  let open Context in
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
                ~constants:consensus_constants (time_to_ms now) consensus_state
                ~local_state:consensus_local_state ~logger )
        in
        let i' = Mina_numbers.Length.succ epoch_data_for_vrf.epoch in
        let new_global_slot = epoch_data_for_vrf.global_slot in
        let next_vrf_check_now = check_next_block_timing new_global_slot i' in
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
                   (Singleton_scheduler.schedule scheduler ~f:next_vrf_check_now) )
              ~produce_block_now:(Fn.compose Deferred.return produce_block_now)
              ~schedule_block_production:(fun (time, data, winner) ->
                Singleton_scheduler.schedule scheduler time ~f:(fun () ->
                    produce_block_now (time, data, winner) ) ;
                Deferred.unit )
              ~next_vrf_check_now:
                (Fn.compose Deferred.return next_vrf_check_now)
              ~context:(module Context)
              ~time_controller ~coinbase_receiver ~ledger_snapshot i slot
            : unit Deferred.t )
  in
  let start () =
    check_next_block_timing Mina_numbers.Global_slot_since_hard_fork.zero
      Mina_numbers.Length.zero ()
  in
  let genesis_state_timestamp = consensus_constants.genesis_state_timestamp in
  (* if the producer starts before genesis, sleep until genesis *)
  let now = Block_time.now time_controller in
  if Block_time.( >= ) now genesis_state_timestamp then start ()
  else
    let time_till_genesis = Block_time.diff genesis_state_timestamp now in
    ignore
      ( Block_time.Timeout.create time_controller time_till_genesis ~f:(fun _ ->
            start () )
        : unit Block_time.Timeout.t )
