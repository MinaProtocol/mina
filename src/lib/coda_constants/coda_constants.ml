[%%import
"/src/config.mlh"]

open Core_kernel

(*Scan state and the following constants cannot be in Genesis_constants.t until 
key generation is moved to runtime_genesis_ledger.exe.
c, ledger_depth, pending_coinbase_depth(calculated from scan state and block 
window duration if tps is given) is used to define typs.
Defining block_window_duration_ms, c here instead of using from Coda_compile_config.t to avoid a dependency cycle*)
[%%inject
"block_window_duration_ms", block_window_duration]

[%%inject
"c", c]

module type S = sig
  module Consensus : sig
    type t =
      { k: int
      ; c: int
      ; delta: int
      ; block_window_duration_ms: Time.Span.t
      ; slots_per_sub_window: int
      ; slots_per_window: int
      ; sub_windows_per_window: int
      ; slots_per_epoch: int
      ; slot_duration_ms: int
      ; epoch_size: int
      ; epoch_duration: Time.Span.t
      ; checkpoint_window_slots_per_year: int
      ; checkpoint_window_size_in_slots: int
      ; delta_duration: Time.Span.t }
  end

  type t =
    { consensus: Consensus.t
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
    ; slots_per_sub_window: int
    ; slots_per_window: int
    ; sub_windows_per_window: int
    ; slots_per_epoch: int
    ; slot_duration_ms: int
    ; epoch_size: int
    ; epoch_duration: Time.Span.t
    ; checkpoint_window_slots_per_year: int
    ; checkpoint_window_size_in_slots: int
    ; delta_duration: Time.Span.t }
end

type t =
  { consensus: Consensus_constants.t
  ; inactivity_ms: int
  ; txpool_max_size: int
  ; genesis_state_timestamp: Time.t }

let create_t (genesis_constants : Genesis_constants.t) : t =
  let sub_windows_per_window = c in
  let slots_per_sub_window = genesis_constants.consensus.k in
  let slots_per_window = sub_windows_per_window * slots_per_sub_window in
  (* Number of slots =24k in ouroboros praos *)
  let slots_per_epoch = 3 * c * genesis_constants.consensus.k in
  (* This is a bit of a hack, see #3232. *)
  let inactivity_ms = block_window_duration_ms * 8 in
  let module Slot = struct
    let duration_ms = block_window_duration_ms
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
    ; c
    ; delta= genesis_constants.consensus.delta
    ; block_window_duration_ms
    ; slots_per_sub_window
    ; slots_per_window
    ; sub_windows_per_window
    ; slots_per_epoch
    ; slot_duration_ms= Slot.duration_ms
    ; epoch_size= Epoch.size
    ; epoch_duration= Epoch.duration
    ; checkpoint_window_slots_per_year= Checkpoint_window.slots_per_year
    ; checkpoint_window_size_in_slots= Checkpoint_window.size_in_slots
    ; delta_duration }
  in
  { consensus
  ; inactivity_ms
  ; txpool_max_size= genesis_constants.runtime.txpool_max_size
  ; genesis_state_timestamp= genesis_constants.runtime.genesis_state_timestamp
  }

let t_ref = ref None

(*This should be set before it can be used. For constants that are compile-time, specify it in coda_compile_config.ml*)
let t () : t = Option.value_exn !t_ref

let compiled_constants_for_test = create_t Genesis_constants.compiled
