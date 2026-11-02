open Core
open Async
open Signature_lib
module Epoch = Mina_numbers.Length
module Global_slot_since_hard_fork = Mina_numbers.Global_slot_since_hard_fork

module type CONTEXT = sig
  val logger : Logger.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

(*Slot number within an epoch*)
module Slot = Mina_numbers.Nat.Make32 ()

(* Can extract both slot numbers and epoch number*)
module Consensus_time = Consensus.Data.Consensus_time

module Block_producer_keys = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t = (Keypair.Stable.V1.t * Public_key.Compressed.Stable.V1.t) list
      [@@deriving sexp]

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t [@@deriving sexp]
end

module Evaluator_status = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t = At of Global_slot_since_hard_fork.Stable.V1.t | Completed

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = At of Global_slot_since_hard_fork.t | Completed
  [@@deriving sexp]
end

module Vrf_evaluation_result = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        { slots_won : Consensus.Data.Slot_won.Stable.V2.t list
        ; evaluator_status : Evaluator_status.Stable.V2.t
        }

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t =
    { slots_won : Consensus.Data.Slot_won.t list
    ; evaluator_status : Evaluator_status.t
    }
end

module Worker_state = struct
  let max_slots_won_queue_length = 100

  (* How many slots before a slot starts its search must finish, leaving time
     for the win to reach the block producer. *)
  let deadline_lead_slots = 2

  type init_arg =
    { constraint_constants : Genesis_constants.Constraint_constants.t
    ; consensus_constants : Consensus.Constants.Stable.Latest.t
    ; conf_dir : string
    ; logger : Logger.t
    ; commit_id : string
    }
  [@@deriving bin_io_unversioned]

  let context_of_config
      ({ constraint_constants
       ; consensus_constants
       ; logger
       ; conf_dir = _
       ; commit_id = _
       } :
        init_arg ) : (module CONTEXT) =
    ( module struct
      let constraint_constants = constraint_constants

      let consensus_constants = consensus_constants

      let logger = logger
    end )

  type progress =
    | Idle
    | Scanning of Global_slot_since_hard_fork.t
    | Completed of { epoch_generation : int; state_version : int }

  type vrf_eval_result = Lost | Won of Consensus.Data.Slot_won.t | Stale

  type t =
    { config : init_arg
    ; slots_won : Consensus.Data.Slot_won.t Queue.t
          (*possibly multiple producers per slot*)
    ; mutable enqueued_wins :
        (Global_slot_since_hard_fork.t * Public_key.Compressed.t) list
    ; mutable progress : progress
    ; mutable epoch_data : Consensus.Data.Epoch_data_for_vrf.t option
    ; mutable block_producer_keys : Block_producer_keys.t
    ; mutable state_changed : unit Ivar.t
    ; mutable slots_won_capacity_available : unit Ivar.t
    ; mutable epoch_generation : int
    ; mutable state_version : int
    }

  let slots_won_queue_full t =
    Queue.length t.slots_won >= max_slots_won_queue_length

  let notify slots_changed_ivar_ref =
    Ivar.fill_if_empty !slots_changed_ivar_ref () ;
    slots_changed_ivar_ref := Ivar.create ()

  let notify_state_changed t =
    t.state_version <- t.state_version + 1 ;
    let state_changed = ref t.state_changed in
    notify state_changed ;
    t.state_changed <- !state_changed

  let notify_slots_won_capacity_available t =
    let slots_won_capacity_available = ref t.slots_won_capacity_available in
    notify slots_won_capacity_available ;
    t.slots_won_capacity_available <- !slots_won_capacity_available

  let wait_for_update t =
    Deferred.choose
      [ Deferred.choice (Ivar.read t.state_changed) Fn.id
      ; Deferred.choice (Ivar.read t.slots_won_capacity_available) Fn.id
      ]

  let mark_progress t progress = t.progress <- progress

  let already_enqueued t slot producer =
    List.exists t.enqueued_wins ~f:(fun (slot', producer') ->
        Global_slot_since_hard_fork.equal slot slot'
        && Public_key.Compressed.equal producer producer' )

  let enqueue_slot_won t (slot_won : Consensus.Data.Slot_won.t)
      ~producer_public_key =
    if not (already_enqueued t slot_won.global_slot producer_public_key) then (
      Queue.enqueue t.slots_won slot_won ;
      t.enqueued_wins <-
        (slot_won.global_slot, producer_public_key) :: t.enqueued_wins )

  let evaluator_status t =
    match t.progress with
    | Scanning slot ->
        Evaluator_status.At slot
    | Completed { epoch_generation; state_version }
      when epoch_generation = t.epoch_generation
           && state_version = t.state_version ->
        Completed
    | Idle | Completed _ -> (
        match t.epoch_data with
        | Some epoch_data ->
            Evaluator_status.At epoch_data.global_slot
        | None ->
            Completed )

  (* The delegators of every block producer key, largest stake first, so that
     a search cut short by its deadline has covered as much stake, and so as
     much chance of winning, as possible. *)
  let delegators_by_stake ~(epoch_data : Consensus.Data.Epoch_data_for_vrf.t)
      ~(keypairs : Block_producer_keys.t) =
    List.concat_map keypairs ~f:(fun ((_, public_key_compressed) as producer) ->
        match
          Public_key.Compressed.Table.find epoch_data.delegatee_table
            public_key_compressed
        with
        | None ->
            []
        | Some delegators ->
            Hashtbl.fold delegators ~init:[]
              ~f:(fun ~key:delegator ~data:account acc ->
                (producer, delegator, account) :: acc ) )
    |> List.sort
         ~compare:(fun
                    (_, delegator1, (account1 : Mina_base.Account.t))
                    (_, delegator2, (account2 : Mina_base.Account.t))
                  ->
           match Currency.Balance.compare account2.balance account1.balance with
           | 0 ->
               Mina_base.Account.Index.compare delegator1 delegator2
           | order ->
               order )

  let evaluate_vrf ~context:(module Context : CONTEXT)
      ~(epoch_data : Consensus.Data.Epoch_data_for_vrf.t) ~delegators
      ~consensus_time ~should_stop =
    let open Context in
    let epoch = epoch_data.epoch in
    let start_global_slot = epoch_data.global_slot in
    let start_global_slot_since_genesis =
      epoch_data.global_slot_since_genesis
    in
    let total_stake = epoch_data.epoch_ledger.total_currency in
    let slot : Slot.t = Slot.of_uint32 @@ Consensus_time.slot consensus_time in
    let global_slot = Consensus_time.to_global_slot consensus_time in
    let global_slot_since_genesis =
      let slot_diff : Mina_numbers.Global_slot_span.t =
        match
          Global_slot_since_hard_fork.diff global_slot start_global_slot
        with
        | None ->
            failwith
              "Checking slot-winner for a slot which is older than the slot in \
               the latest consensus state. System time might be out-of-sync"
        | Some diff ->
            diff
      in
      Mina_numbers.Global_slot_since_genesis.add start_global_slot_since_genesis
        slot_diff
    in
    [%log info] "Checking VRF evaluations for epoch: $epoch, slot: $slot"
      ~metadata:
        [ ("epoch", `Int (Epoch.to_int epoch))
        ; ("slot", `Int (Slot.to_int slot))
        ] ;
    let%map result =
      Interruptible.force
        (Consensus.Data.Vrf.check_delegators
           ~context:(module Context)
           ~should_stop ~global_slot ~seed:epoch_data.epoch_seed ~total_stake
           ~producer_private_key:(fun ((keypair : Keypair.t), _) ->
             keypair.private_key )
           delegators )
    in
    match result with
    | Error () ->
        Stale
    | Ok None ->
        Lost
    | Ok
        (Some
          ( `Vrf_eval _vrf_string
          , `Vrf_output vrf_result
          , `Delegator delegator
          , `Producer (keypair, _) ) ) ->
        [%log info] "Won slot %d in epoch %d" (Slot.to_int slot)
          (Epoch.to_int epoch) ;
        Won
          Consensus.Data.Slot_won.
            { delegator
            ; producer = keypair
            ; global_slot
            ; global_slot_since_genesis
            ; vrf_result
            }

  let run_loop t =
    let (module Context) = context_of_config t.config in
    let open Context in
    let start_consensus_time (epoch_data : Consensus.Data.Epoch_data_for_vrf.t)
        =
      Consensus.Data.Consensus_time.(
        of_global_slot ~constants:consensus_constants epoch_data.global_slot)
    in
    let time_controller = Block_time.Controller.basic ~logger in
    let sorted_delegators = ref None in
    let delegators_for ~epoch_data ~generation ~state_version =
      match !sorted_delegators with
      | Some (cached_generation, cached_state_version, delegators)
        when cached_generation = generation
             && cached_state_version = state_version ->
          delegators
      | _ ->
          let delegators =
            delegators_by_stake ~epoch_data ~keypairs:t.block_producer_keys
          in
          sorted_delegators := Some (generation, state_version, delegators) ;
          delegators
    in
    let slot_duration_ms =
      Block_time.Span.to_ms consensus_constants.slot_duration_ms
    in
    (* A win is only useful if it reaches the block producer before its slot
       starts, so the search for a slot stops [deadline_lead_slots] slots
       before the slot starts, keeping the best win found by then. A slot too
       close for that, such as the first slots after new epoch data arrives,
       is instead searched until its midpoint. A slot past its midpoint is
       skipped. *)
    let search_deadline consensus_time =
      let current_time = Block_time.now time_controller in
      let slot_start =
        Consensus_time.start_time ~constants:consensus_constants consensus_time
      in
      let lead_deadline =
        Block_time.sub slot_start
          (Block_time.Span.of_ms
             Int64.(of_int deadline_lead_slots * slot_duration_ms) )
      in
      let midpoint =
        Block_time.add slot_start
          (Block_time.Span.of_ms Int64.(slot_duration_ms / of_int 2))
      in
      if Block_time.(current_time < lead_deadline) then Some lead_deadline
      else if Block_time.(current_time < midpoint) then Some midpoint
      else None
    in
    let rec next_searchable_slot consensus_time =
      match search_deadline consensus_time with
      | Some deadline ->
          (consensus_time, deadline)
      | None ->
          next_searchable_slot (Consensus_time.succ consensus_time)
    in
    let skip_unsearchable_slots consensus_time =
      let ((next_slot, _) as next) = next_searchable_slot consensus_time in
      if Consensus_time.compare next_slot consensus_time <> 0 then
        [%log warn]
          "Skipping VRF evaluation from slot $skipped_from to slot $next_slot, \
           as the skipped slots are past their search deadline"
          ~metadata:
            [ ( "skipped_from"
              , Global_slot_since_hard_fork.to_yojson
                  (Consensus_time.to_global_slot consensus_time) )
            ; ( "next_slot"
              , Global_slot_since_hard_fork.to_yojson
                  (Consensus_time.to_global_slot next_slot) )
            ] ;
      next
    in
    let wait_for_state_change () = Ivar.read t.state_changed in
    let scanning generation state_version consensus_time =
      Some (`Scanning (generation, state_version, consensus_time))
    in
    let completed generation state_version =
      Some (`Completed (generation, state_version))
    in
    let next_slot generation state_version consensus_time =
      scanning generation state_version (Consensus_time.succ consensus_time)
    in
    let rec loop current =
      match t.epoch_data with
      | None ->
          mark_progress t Idle ;
          let%bind () = wait_for_state_change () in
          loop None
      | Some epoch_data -> (
          let generation = t.epoch_generation in
          let state_version = t.state_version in
          match current with
          | Some (`Completed (completed_generation, completed_state_version))
            when completed_generation = generation
                 && completed_state_version = state_version ->
              mark_progress t
                (Completed { epoch_generation = generation; state_version }) ;
              let%bind () = wait_for_state_change () in
              loop current
          | _ ->
              let consensus_time =
                match current with
                | Some
                    (`Scanning
                      ( scanning_generation
                      , scanning_state_version
                      , consensus_time ) )
                  when scanning_generation = generation
                       && scanning_state_version = state_version ->
                    consensus_time
                | _ ->
                    [%log info] "Starting VRF evaluation for epoch: $epoch"
                      ~metadata:[ ("epoch", Epoch.to_yojson epoch_data.epoch) ] ;
                    start_consensus_time epoch_data
              in
              let consensus_time, deadline =
                skip_unsearchable_slots consensus_time
              in
              let slot = Slot.of_uint32 @@ Consensus_time.slot consensus_time in
              let global_slot =
                Consensus_time.to_uint32 consensus_time
                |> Global_slot_since_hard_fork.of_uint32
              in
              let epoch' = Consensus_time.epoch consensus_time in
              if Epoch.(epoch' > epoch_data.epoch) then (
                if
                  t.epoch_generation = generation
                  && t.state_version = state_version
                then
                  mark_progress t
                    (Completed { epoch_generation = generation; state_version }) ;
                loop (completed generation state_version) )
              else if slots_won_queue_full t then (
                mark_progress t (Scanning global_slot) ;
                [%log' warn t.config.logger]
                  "Pausing VRF evaluation because $num_slots_won slots are \
                   waiting to be polled"
                  ~metadata:
                    [ ("num_slots_won", `Int (Queue.length t.slots_won)) ] ;
                let%bind () = wait_for_update t in
                loop current )
              else (
                mark_progress t (Scanning global_slot) ;
                let start = Time.now () in
                let delegators =
                  delegators_for ~epoch_data ~generation ~state_version
                in
                let%bind slot_won =
                  evaluate_vrf
                    ~context:(module Context)
                    ~epoch_data ~delegators ~consensus_time
                    ~should_stop:(fun () ->
                      Block_time.(now time_controller >= deadline) )
                in
                if Block_time.(now time_controller >= deadline) then
                  [%log warn]
                    "VRF evaluation for slot $slot reached its deadline, and \
                     may not have checked every delegator"
                    ~metadata:[ ("slot", Slot.to_yojson slot) ] ;
                if
                  t.epoch_generation <> generation
                  || t.state_version <> state_version
                then loop None
                else
                  match slot_won with
                  | Stale ->
                      loop None
                  | Lost ->
                      [%log info] "Did not win slot $slot, took $time ms"
                        ~metadata:
                          [ ( "time"
                            , `Float Time.(Span.to_ms (diff (now ()) start)) )
                          ; ("slot", Slot.to_yojson slot)
                          ] ;
                      loop (next_slot generation state_version consensus_time)
                  | Won slot_won ->
                      [%log info] "Won a slot $slot, took $time ms"
                        ~metadata:
                          [ ( "time"
                            , `Float Time.(Span.to_ms (diff (now ()) start)) )
                          ; ("slot", Slot.to_yojson slot)
                          ] ;
                      enqueue_slot_won t slot_won
                        ~producer_public_key:
                          (Public_key.compress slot_won.producer.public_key) ;
                      loop (next_slot generation state_version consensus_time) )
          )
    in
    loop None

  let create config =
    { config
    ; slots_won = Queue.create ~capacity:max_slots_won_queue_length ()
    ; enqueued_wins = []
    ; progress = Idle
    ; epoch_data = None
    ; block_producer_keys = []
    ; state_changed = Ivar.create ()
    ; slots_won_capacity_available = Ivar.create ()
    ; epoch_generation = 0
    ; state_version = 0
    }
end

module Functions = struct
  type ('i, 'o) t =
    'i Bin_prot.Type_class.t
    * 'o Bin_prot.Type_class.t
    * (Worker_state.t -> 'i -> 'o Deferred.t)

  let create input output f : ('i, 'o) t = (input, output, f)

  let set_new_epoch_state =
    create Consensus.Data.Epoch_data_for_vrf.Stable.Latest.bin_t Unit.bin_t
      (fun w e ->
        let logger = w.config.logger in
        let update () =
          [%log info]
            "Updating epoch data for the VRF evaluation for epoch $epoch"
            ~metadata:[ ("epoch", Epoch.to_yojson e.epoch) ] ;
          let reset_enqueued_wins =
            match w.epoch_data with
            | Some current ->
                Epoch.(e.epoch > current.epoch)
            | None ->
                true
          in
          w.epoch_data <- Some e ;
          w.epoch_generation <- w.epoch_generation + 1 ;
          if reset_enqueued_wins then w.enqueued_wins <- [] ;
          w.progress <- Worker_state.Idle ;
          Worker_state.notify_state_changed w ;
          Deferred.unit
        in
        match w.epoch_data with
        | None ->
            update ()
        | Some current ->
            if Epoch.(succ e.epoch > current.epoch) then update ()
            else (
              [%log info]
                "Received epoch data for current epoch $epoch. Skipping "
                ~metadata:[ ("epoch", Epoch.to_yojson e.epoch) ] ;
              Deferred.unit ) )

  let slots_won_so_far =
    create Unit.bin_t Vrf_evaluation_result.Stable.Latest.bin_t (fun w () ->
        let slots_won = Queue.to_list w.slots_won in
        [%log' info w.config.logger]
          !"Slots won evaluator: %{sexp: Consensus.Data.Slot_won.t list}"
          slots_won ;
        Queue.clear w.slots_won ;
        Worker_state.notify_slots_won_capacity_available w ;
        let evaluator_status = Worker_state.evaluator_status w in
        return Vrf_evaluation_result.{ slots_won; evaluator_status } )

  let update_block_producer_keys =
    create Block_producer_keys.Stable.Latest.bin_t Unit.bin_t (fun w e ->
        let logger = w.config.logger in
        [%log info] "Updating block producer keys" ;
        w.block_producer_keys <- e ;
        Worker_state.notify_state_changed w ;
        Deferred.unit )
end

module Worker = struct
  module T = struct
    type 'worker functions =
      { set_new_epoch_state :
          ( 'worker
          , Consensus.Data.Epoch_data_for_vrf.t
          , unit )
          Rpc_parallel.Function.t
      ; slots_won_so_far :
          ('worker, unit, Vrf_evaluation_result.t) Rpc_parallel.Function.t
      ; update_block_producer_keys :
          ('worker, Block_producer_keys.t, unit) Rpc_parallel.Function.t
      }

    module Worker_state = Worker_state

    module Connection_state = struct
      type init_arg = unit [@@deriving bin_io_unversioned]

      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
               with type worker_state := Worker_state.t
                and type connection_state := Connection_state.t) =
    struct
      let functions =
        let f (i, o, f) =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state:_ i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        let open Functions in
        { set_new_epoch_state = f set_new_epoch_state
        ; slots_won_so_far = f slots_won_so_far
        ; update_block_producer_keys = f update_block_producer_keys
        }

      let init_worker_state (init_arg : Worker_state.init_arg) =
        let logger = init_arg.logger in
        let max_size = 200 * 1024 * 1024 in
        let num_rotate = 1 in
        Logger.Consumer_registry.register ~id:"default"
          ~commit_id:init_arg.commit_id ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:init_arg.conf_dir
               ~log_filename:"mina-vrf-evaluator.log" ~max_size ~num_rotate )
          () ;
        [%log info] "Vrf_evaluator started" ;
        let worker_state = Worker_state.create init_arg in
        don't_wait_for (Worker_state.run_loop worker_state) ;
        return worker_state

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end

  include Rpc_parallel.Make (T)
end

type t = { connection : Worker.Connection.t; process : Process.t }

let update_block_producer_keys { connection; process = _ } ~keypairs =
  Worker.Connection.run connection
    ~f:Worker.functions.update_block_producer_keys
    ~arg:(Keypair.And_compressed_pk.Set.to_list keypairs)

let create ~constraint_constants ~pids ~consensus_constants ~conf_dir ~logger
    ~keypairs ~commit_id =
  let on_failure err =
    [%log error] "VRF evaluator process failed with error $err"
      ~metadata:[ ("err", Error_json.error_to_yojson err) ] ;
    Error.raise err
  in
  [%log info] "Starting a new vrf-evaluator process" ;
  let%bind connection, process =
    Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 1.)
      ~on_failure ~shutdown_on:Connection_closed ~connection_state_init_arg:()
      { constraint_constants; consensus_constants; conf_dir; logger; commit_id }
  in
  [%log info]
    "Daemon started process of kind $process_kind with pid $vrf_evaluator_pid"
    ~metadata:
      [ ("vrf_evaluator_pid", `Int (Process.pid process |> Pid.to_int))
      ; ( "process_kind"
        , `String Child_processes.Termination.(show_process_kind Vrf_evaluator)
        )
      ] ;
  Child_processes.Termination.register_process pids process
    Child_processes.Termination.Vrf_evaluator ;

  let pid = Process.pid process in
  [%log info] "VRF evaluator process has PID %d" (Pid.to_int pid) ;
  Mina_metrics.Process_memory.Vrf_evaluator.set_pid pid ;
  don't_wait_for
  @@ Pipe.iter
       (Process.stdout process |> Reader.pipe)
       ~f:(fun stdout ->
         return
         @@ [%log debug] "Vrf_evaluator stdout: $stdout"
              ~metadata:[ ("stdout", `String stdout) ] ) ;
  don't_wait_for
  @@ Pipe.iter
       (Process.stderr process |> Reader.pipe)
       ~f:(fun stderr ->
         return
         @@ [%log error] "Vrf_evaluator stderr: $stderr"
              ~metadata:[ ("stderr", `String stderr) ] ) ;
  let t = { connection; process } in
  let%map _ = update_block_producer_keys ~keypairs t in
  t

let set_new_epoch_state { connection; process = _ } ~epoch_data_for_vrf =
  Worker.Connection.run connection ~f:Worker.functions.set_new_epoch_state
    ~arg:epoch_data_for_vrf

let slots_won_so_far { connection; process = _ } =
  Worker.Connection.run connection ~f:Worker.functions.slots_won_so_far ~arg:()
