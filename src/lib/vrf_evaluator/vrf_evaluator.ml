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

  type t =
    { config : init_arg
    ; slots_won : Consensus.Data.Slot_won.t Queue.t
          (*possibly multiple producers per slot*)
    ; mutable current_slot : Global_slot_since_hard_fork.t option
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

  let evaluate_vrf ~context:(module Context : CONTEXT)
      ~(epoch_data : Consensus.Data.Epoch_data_for_vrf.t) ~keypairs
      ~consensus_time =
    let open Context in
    let epoch = epoch_data.epoch in
    let start_global_slot = epoch_data.global_slot in
    let start_global_slot_since_genesis = epoch_data.global_slot_since_genesis in
    let delegatee_table = epoch_data.delegatee_table in
    let total_stake = epoch_data.epoch_ledger.total_currency in
    (* Try vrfs for all keypairs that are unseen within this slot until one wins or all lose *)
    (* TODO: Don't do this, and instead pick the one that has the highest chance of winning. See #2573 *)
    let slot : Slot.t = Slot.of_uint32 @@ Consensus_time.slot consensus_time in
    let global_slot = Consensus_time.to_global_slot consensus_time in
    [%log info] "Checking VRF evaluations for epoch: $epoch, slot: $slot"
      ~metadata:
        [ ("epoch", `Int (Epoch.to_int epoch))
        ; ("slot", `Int (Slot.to_int slot))
        ] ;
    let rec go = function
      | [] ->
          Deferred.return None
      | ((keypair : Keypair.t), public_key_compressed) :: keypairs -> (
          let global_slot_since_genesis =
            let slot_diff : Mina_numbers.Global_slot_span.t =
              match
                Global_slot_since_hard_fork.diff global_slot start_global_slot
              with
              | None ->
                  failwith
                    "Checking slot-winner for a slot which is older than the \
                     slot in the latest consensus state. System time might be \
                     out-of-sync"
              | Some diff ->
                  diff
            in
            Mina_numbers.Global_slot_since_genesis.add
              start_global_slot_since_genesis slot_diff
          in
          [%log info] "Checking VRF evaluations at epoch: $epoch, slot: $slot"
            ~metadata:
              [ ("epoch", `Int (Epoch.to_int epoch))
              ; ("slot", `Int (Slot.to_int slot))
              ] ;
          let%bind result =
            Interruptible.force
              (Consensus.Data.Vrf.check
                 ~context:(module Context)
                 ~global_slot ~seed:epoch_data.epoch_seed
                 ~get_delegators:
                   (Public_key.Compressed.Table.find delegatee_table)
                 ~producer_private_key:keypair.private_key
                 ~producer_public_key:public_key_compressed ~total_stake )
          in
          match result with
          | Error () ->
              go keypairs
          | Ok None ->
              go keypairs
          | Ok
              (Some
                 ( `Vrf_eval _vrf_string
                 , `Vrf_output vrf_result
                 , `Delegator delegator )) ->
              [%log info] "Won slot %d in epoch %d" (Slot.to_int slot)
                (Epoch.to_int epoch) ;
              let slot_won =
                Consensus.Data.Slot_won.
                  { delegator
                  ; producer = keypair
                  ; global_slot
                  ; global_slot_since_genesis
                  ; vrf_result
                  }
              in
              Deferred.return (Some slot_won) )
    in
    go keypairs

  let run_loop t =
    let (module Context) = context_of_config t.config in
    let open Context in
    let start_consensus_time (epoch_data : Consensus.Data.Epoch_data_for_vrf.t) =
      Consensus.Data.Consensus_time.(
        of_global_slot ~constants:consensus_constants epoch_data.global_slot)
    in
    let wait_for_state_change () = Ivar.read t.state_changed in
    let rec loop current =
      match t.epoch_data with
      | None ->
          let%bind () = wait_for_state_change () in
          loop None
      | Some epoch_data -> (
          let generation = t.epoch_generation in
          match current with
          | Some (`Completed completed_generation)
            when completed_generation = generation ->
              let%bind () = wait_for_state_change () in
              loop current
          | _ ->
              let consensus_time =
                match current with
                | Some (`Scanning (scanning_generation, consensus_time))
                  when scanning_generation = generation ->
                    consensus_time
                | _ ->
                    [%log info] "Starting VRF evaluation for epoch: $epoch"
                      ~metadata:[ ("epoch", Epoch.to_yojson epoch_data.epoch) ] ;
                    start_consensus_time epoch_data
              in
              if slots_won_queue_full t then (
                [%log' warn t.config.logger]
                  "Pausing VRF evaluation because $num_slots_won slots are \
                   waiting to be polled"
                  ~metadata:
                    [ ("num_slots_won", `Int (Queue.length t.slots_won)) ] ;
                let%bind () = wait_for_update t in
                loop current )
              else
                let slot =
                  Slot.of_uint32 @@ Consensus_time.slot consensus_time
                in
                t.current_slot <-
                  Some
                    ( Consensus_time.to_uint32 consensus_time
                    |> Global_slot_since_hard_fork.of_uint32 ) ;
                let epoch' = Consensus_time.epoch consensus_time in
                if Epoch.(epoch' > epoch_data.epoch) then (
                  if t.epoch_generation = generation then t.current_slot <- None ;
                  loop (Some (`Completed generation)) )
                else
                  let start = Time.now () in
                  let keypairs = t.block_producer_keys in
                  let%bind slot_won =
                    evaluate_vrf ~context:(module Context) ~epoch_data ~keypairs
                      ~consensus_time
                  in
                  if t.epoch_generation <> generation then loop None
                  else
                    match slot_won with
                    | None ->
                        [%log info] "Did not win slot $slot, took $time ms"
                          ~metadata:
                            [ ( "time"
                              , `Float Time.(Span.to_ms (diff (now ()) start)) )
                            ; ("slot", Slot.to_yojson slot)
                            ] ;
                        loop
                          (Some
                             (`Scanning
                               ( generation
                               , Consensus_time.succ consensus_time ) ) )
                    | Some slot_won ->
                        [%log info] "Won a slot $slot, took $time ms"
                          ~metadata:
                            [ ( "time"
                              , `Float Time.(Span.to_ms (diff (now ()) start)) )
                            ; ("slot", Slot.to_yojson slot)
                            ] ;
                        Queue.enqueue t.slots_won slot_won ;
                        loop
                          (Some
                             (`Scanning
                               ( generation
                               , Consensus_time.succ consensus_time ) ) ) )
    in
    loop None

  let create config =
    { config
    ; slots_won = Queue.create ~capacity:max_slots_won_queue_length ()
    ; current_slot = None
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
          Queue.clear w.slots_won ;
          Worker_state.notify_slots_won_capacity_available w ;
          w.current_slot <- None ;
          w.epoch_data <- Some e ;
          w.epoch_generation <- w.epoch_generation + 1 ;
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
        let evaluator_status =
          match w.current_slot with
          | Some slot ->
              Evaluator_status.At slot
          | None ->
              Completed
        in
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
