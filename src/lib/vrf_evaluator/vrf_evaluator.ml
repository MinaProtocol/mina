open Core
open Async
open Signature_lib
module Epoch = Mina_numbers.Length
module Global_slot = Mina_numbers.Global_slot

module type CONTEXT = sig
  val logger : Logger.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val consensus_constants : Consensus.Constants.t
end

(*Slot number within an epoch*)
module Slot = Mina_numbers.Global_slot

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

    module V1 = struct
      type t = At of Global_slot.Stable.V1.t | Completed

      let to_latest = Fn.id
    end
  end]

  type t = Stable.Latest.t = At of Global_slot.t | Completed [@@deriving sexp]
end

module Vrf_evaluation_result = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V1 = struct
      type t =
        { slots_won : Consensus.Data.Slot_won.Stable.V1.t list
        ; evaluator_status : Evaluator_status.Stable.V1.t
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
  type init_arg =
    { constraint_constants : Genesis_constants.Constraint_constants.t
    ; consensus_constants : Consensus.Constants.Stable.Latest.t
    ; conf_dir : string
    ; logger : Logger.Stable.Latest.t
    }
  [@@deriving bin_io_unversioned]

  let context_of_config
      ({ constraint_constants; consensus_constants; logger; conf_dir = _ } :
        init_arg ) : (module CONTEXT) =
    ( module struct
      let constraint_constants = constraint_constants

      let consensus_constants = consensus_constants

      let logger = logger
    end )

  type t =
    { config : init_arg
    ; mutable last_checked_slot_and_epoch :
        (Epoch.t * Slot.t) Public_key.Compressed.Table.t
    ; slots_won : Consensus.Data.Slot_won.t Queue.t
          (*possibly multiple producers per slot*)
    ; mutable current_slot : Global_slot.t option
    ; mutable epoch_data :
        unit Ivar.t * Consensus.Data.Epoch_data_for_vrf.t option
    ; mutable block_producer_keys : Block_producer_keys.t
    }

  let make_last_checked_slot_and_epoch_table old_table new_keys ~default =
    let module Set = Public_key.Compressed.Set in
    let module Table = Public_key.Compressed.Table in
    let last_checked_slot_and_epoch = Table.create () in
    List.iter new_keys ~f:(fun (_, pk) ->
        let data = Option.value (Table.find old_table pk) ~default in
        Table.add_exn last_checked_slot_and_epoch ~key:pk ~data ) ;
    last_checked_slot_and_epoch

  let seen_slot last_checked_slot_and_epoch epoch slot =
    let module Table = Public_key.Compressed.Table in
    let unseens =
      Table.to_alist last_checked_slot_and_epoch
      |> List.filter_map ~f:(fun (pk, last_checked_epoch_and_slot) ->
             let i =
               Tuple2.compare ~cmp1:Epoch.compare ~cmp2:Slot.compare
                 last_checked_epoch_and_slot (epoch, slot)
             in
             if i > 0 then None
             else if i = 0 then
               (*vrf evaluation was stopped at this point because it was either the end of the epoch or the key won this slot; re-check this slot when staking keys are reset so that we don't skip producing block. This will not occur in the normal flow because [slot] will be greater than the last-checked-slot*)
               Some pk
             else (
               Table.set last_checked_slot_and_epoch ~key:pk ~data:(epoch, slot) ;
               Some pk ) )
    in
    match unseens with
    | [] ->
        `All_seen
    | nel ->
        `Unseen (Public_key.Compressed.Set.of_list nel)

  let evaluate
      ( { config
        ; slots_won
        ; block_producer_keys
        ; epoch_data = interrupt_ivar, epoch_data
        ; _
        } as t ) : (unit, unit) Interruptible.t =
    let (module Context) = context_of_config config in
    let open Context in
    match epoch_data with
    | None ->
        Interruptible.return ()
    | Some epoch_data ->
        let open Interruptible.Let_syntax in
        let%bind () =
          Interruptible.lift Deferred.unit (Ivar.read interrupt_ivar)
        in
        let module Slot = Mina_numbers.Global_slot in
        let epoch = epoch_data.epoch in
        [%log info] "Starting VRF evaluation for epoch: $epoch"
          ~metadata:[ ("epoch", Epoch.to_yojson epoch) ] ;
        let keypairs = block_producer_keys in
        let start_global_slot = epoch_data.global_slot in
        let start_global_slot_since_genesis =
          epoch_data.global_slot_since_genesis
        in
        let delegatee_table = epoch_data.delegatee_table in
        (*slot in the epoch*)
        let start_consensus_time =
          Consensus.Data.Consensus_time.(
            of_global_slot ~constants:consensus_constants start_global_slot)
        in
        let total_stake = epoch_data.epoch_ledger.total_currency in
        let evaluate_vrf ~consensus_time =
          (* Try vrfs for all keypairs that are unseen within this slot until one wins or all lose *)
          (* TODO: Don't do this, and instead pick the one that has the highest chance of winning. See #2573 *)
          let slot = Consensus_time.slot consensus_time in
          let global_slot = Consensus_time.to_global_slot consensus_time in
          [%log info] "Checking VRF evaluations for epoch: $epoch, slot: $slot"
            ~metadata:
              [ ("epoch", `Int (Epoch.to_int epoch))
              ; ("slot", `Int (Slot.to_int slot))
              ] ;
          let rec go = function
            | [] ->
                Interruptible.return None
            | ((keypair : Keypair.t), public_key_compressed) :: keypairs -> (
                let global_slot_since_genesis =
                  let slot_diff =
                    match Global_slot.sub global_slot start_global_slot with
                    | None ->
                        failwith
                          "Checking slot-winner for a slot which is older than \
                           the slot in the latest consensus state. System time \
                           might be out-of-sync"
                    | Some diff ->
                        diff
                  in
                  Global_slot.add start_global_slot_since_genesis slot_diff
                in
                [%log info]
                  "Checking VRF evaluations at epoch: $epoch, slot: $slot"
                  ~metadata:
                    [ ("epoch", `Int (Epoch.to_int epoch))
                    ; ("slot", `Int (Slot.to_int slot))
                    ] ;
                match%bind
                  Consensus.Data.Vrf.check
                    ~context:(module Context)
                    ~global_slot ~seed:epoch_data.epoch_seed
                    ~get_delegators:
                      (Public_key.Compressed.Table.find delegatee_table)
                    ~producer_private_key:keypair.private_key
                    ~producer_public_key:public_key_compressed ~total_stake
                with
                | None ->
                    go keypairs
                | Some
                    ( `Vrf_eval _vrf_string
                    , `Vrf_output vrf_result
                    , `Delegator delegator ) ->
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
                    Interruptible.return (Some slot_won) )
          in
          go keypairs
        in
        let rec find_winning_slot (consensus_time : Consensus_time.t) =
          let slot = Consensus_time.slot consensus_time in
          let global_slot = Consensus_time.to_global_slot consensus_time in
          t.current_slot <- Some global_slot ;
          let epoch' = Consensus_time.epoch consensus_time in
          if Epoch.(epoch' > epoch) then (
            t.current_slot <- None ;
            Interruptible.return () )
          else
            let start = Time.now () in
            match%bind evaluate_vrf ~consensus_time with
            | None ->
                [%log info] "Did not win slot $slot, took $time ms"
                  ~metadata:
                    [ ("time", `Float Time.(Span.to_ms (diff (now ()) start)))
                    ; ("slot", Slot.to_yojson slot)
                    ] ;
                find_winning_slot (Consensus_time.succ consensus_time)
            | Some slot_won ->
                [%log info] "Won a slot $slot, took $time ms"
                  ~metadata:
                    [ ("time", `Float Time.(Span.to_ms (diff (now ()) start)))
                    ; ("slot", Slot.to_yojson slot)
                    ] ;
                Queue.enqueue slots_won slot_won ;
                find_winning_slot (Consensus_time.succ consensus_time)
        in
        find_winning_slot start_consensus_time

  let create config =
    { config
    ; last_checked_slot_and_epoch = Public_key.Compressed.Table.create ()
    ; slots_won =
        Queue.create
          ~capacity:
            (Global_slot.to_int config.consensus_constants.slots_per_epoch)
          ()
    ; current_slot = None
    ; epoch_data = (Ivar.create (), None)
    ; block_producer_keys = []
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
          let interrupt_ivar, _ = w.epoch_data in
          Ivar.fill_if_empty interrupt_ivar () ;
          Queue.clear w.slots_won ;
          w.current_slot <- None ;
          w.epoch_data <- (Ivar.create (), Some e) ;
          Interruptible.don't_wait_for (Worker_state.evaluate w) ;
          Deferred.unit
        in
        match w.epoch_data with
        | _, None ->
            update ()
        | _, Some current ->
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
        (*TODO: Interrupt the evaluation here when we handle key updated*)
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
          ~processor:(Logger.Processor.raw ())
          ~transport:
            (Logger_file_system.dumb_logrotate ~directory:init_arg.conf_dir
               ~log_filename:"mina-vrf-evaluator.log" ~max_size ~num_rotate ) ;
        [%log info] "Vrf_evaluator started" ;
        return (Worker_state.create init_arg)

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
    ~keypairs =
  let on_failure err =
    [%log error] "VRF evaluator process failed with error $err"
      ~metadata:[ ("err", Error_json.error_to_yojson err) ] ;
    Error.raise err
  in
  [%log info] "Starting a new vrf-evaluator process" ;
  let%bind connection, process =
    Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 1.)
      ~on_failure ~shutdown_on:Connection_closed ~connection_state_init_arg:()
      { constraint_constants; consensus_constants; conf_dir; logger }
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
