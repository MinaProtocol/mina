open Core_kernel

module type S = sig
  module Consensus : sig
    type t =
      { k: int
      ; c: int
      ; delta: int
      ; block_window_duration_ms: Time.Span.t
      ; sub_windows_per_window: int
      ; slots_per_sub_window: int
      ; slots_per_window: int
      ; slots_per_epoch: int
      ; slot_duration_ms: int
      ; epoch_size: int
      ; epoch_duration: Time.Span.t
      ; checkpoint_window_slots_per_year: int
      ; checkpoint_window_size_in_slots: int
      ; delta_duration: Time.Span.t }
  end

  module Scan_state : sig
    type t =
      { work_delay: int
      ; transaction_capacity_log_2: int
      ; pending_coinbase_depth: int }
  end

  type t =
    { consensus: Consensus.t
    ; scan_state: Scan_state.t
    ; inactivity_ms: int
    ; txpool_max_size: int
    ; genesis_state_timestamp: Time.t }

  val t : t Lazy.t
end

(** Consensus constants are defined with a single letter (latin or greek) based on
 * their usage in the Ouroboros suite of papers *)
module Consensus_constants = struct
  type t =
    { k: int
    ; c: int
    ; delta: int
    ; block_window_duration_ms: int
    ; sub_windows_per_window: int
    ; slots_per_sub_window: int
    ; slots_per_window: int
    ; slots_per_epoch: int
    ; slot_duration_ms: int
    ; epoch_size: int
    ; epoch_duration: Time.Span.t
    ; checkpoint_window_slots_per_year: int
    ; checkpoint_window_size_in_slots: int
    ; delta_duration: Time.Span.t }
end

(*transaction_capacity_log_2: Log of the capacity of transactions per
transition. 1 will only work if we don't have prover fees. 2 will work with
prover fees, but not if we want a transaction included in every block. At least 
3 ensures a transaction per block and the staged-ledger unit tests pass.
work_delay: All the proofs before the last <work_delay> blocks are required to
be completed to add transactions. <work_delay> is the minimum number of blocks
and will increase if the throughput is less. If delay = 0, then all the work
that was added to the scan state in the previous block is expected to be
completed and included in the current block if any transactions/coinbase are to
be included. Having a delay >= 1 means there's at least two block times for
completing the proofs *)
module Scan_state_constants = struct
  type t =
    { work_delay: int
    ; transaction_capacity_log_2: int
    ; pending_coinbase_depth: int }
end

type t =
  { consensus: Consensus_constants.t
  ; scan_state: Scan_state_constants.t
  ; inactivity_ms: int
  ; txpool_max_size: int
  ; genesis_state_timestamp: Time.t }

let create_t (genesis_constants : Genesis_constants.t) : t =
  let sub_windows_per_window = genesis_constants.consensus.c in
  let slots_per_sub_window = genesis_constants.consensus.k in
  let slots_per_window = sub_windows_per_window * slots_per_sub_window in
  (* Number of slots =24k in ouroboros praos *)
  let slots_per_epoch =
    3 * genesis_constants.consensus.c * genesis_constants.consensus.k
  in
  (* This is a bit of a hack, see #3232. *)
  let inactivity_ms = genesis_constants.runtime.block_window_duration_ms * 8 in
  let module Slot = struct
    let duration_ms = genesis_constants.runtime.block_window_duration_ms
  end in
  let module Epoch = struct
    let size = slots_per_epoch

    (* Amount of time in total for an epoch *)
    let duration = Time.Span.of_ms (Float.of_int (Slot.duration_ms * size))
  end in
  let module Checkpoint_window = struct
    let per_year = 12

    let slots_per_year =
      let one_year_ms = Core.Time.Span.(to_ms (of_day 365.)) |> Float.to_int in
      one_year_ms / Slot.duration_ms

    let size_in_slots =
      assert (slots_per_year mod per_year = 0) ;
      slots_per_year / per_year
  end in
  let delta_duration =
    Time.Span.of_ms
      (Float.of_int (Slot.duration_ms * genesis_constants.consensus.delta))
  in
  let consensus =
    { Consensus_constants.k= genesis_constants.consensus.k
    ; c= genesis_constants.consensus.c
    ; delta= genesis_constants.consensus.delta
    ; block_window_duration_ms=
        genesis_constants.runtime.block_window_duration_ms
    ; sub_windows_per_window
    ; slots_per_sub_window
    ; slots_per_window
    ; slots_per_epoch
    ; slot_duration_ms= Slot.duration_ms
    ; epoch_size= Epoch.size
    ; epoch_duration= Epoch.duration
    ; checkpoint_window_slots_per_year= Checkpoint_window.slots_per_year
    ; checkpoint_window_size_in_slots= Checkpoint_window.size_in_slots
    ; delta_duration }
  in
  let transaction_capacity_log_2 =
    match genesis_constants.scan_state.capacity with
    | `Transaction_capacity_log_2 c ->
        c
    | `Tps_goal_x10 tps_goal_x10 ->
        let max_coinbases = 2 in
        (* block_window_duration is in milliseconds, so divide by 1000
       divide by 10 again because we have tps * 10
     *)
        let max_user_commands_per_block =
          tps_goal_x10 * genesis_constants.runtime.block_window_duration_ms
          / (1000 * 10)
        in
        1
        + Core_kernel.Int.ceil_log2
            (max_user_commands_per_block + max_coinbases)
  in
  let pending_coinbase_depth =
    Core_kernel.Int.ceil_log2
      ( (transaction_capacity_log_2 + 1)
        * (genesis_constants.scan_state.work_delay + 1)
      + 1 )
  in
  let scan_state =
    { Scan_state_constants.work_delay= genesis_constants.scan_state.work_delay
    ; transaction_capacity_log_2
    ; pending_coinbase_depth }
  in
  { consensus
  ; scan_state
  ; inactivity_ms
  ; txpool_max_size= genesis_constants.runtime.txpool_max_size
  ; genesis_state_timestamp= genesis_constants.runtime.genesis_state_timestamp
  }

let t_ref = ref None

(*This should be set before it can be used. For constants that are compile-time, specify it in coda_compile_config.ml*)
let t () : t = Option.value_exn !t_ref

let compiled_constants_for_test = create_t Genesis_constants.compiled
