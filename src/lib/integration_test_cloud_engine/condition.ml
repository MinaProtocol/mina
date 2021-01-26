open Core_kernel
open Integration_test_lib

module Node = Kubernetes_network.Node

module Network_state = struct
  (* TODO: Just replace the first 3 fields here with Protocol_state *)
  type t =
    { block_height: int
    ; epoch: int
    ; global_slot: int
    ; snarked_ledgers_generated: int
    ; blocks_generated: int
    ; node_initialization: bool String.Map.t }
end

module Network_time_span = struct
  type t = Epochs of int | Slots of int | Literal of Time.Span.t | None

  let to_span t ~(constants : Test_config.constants) =
    let open Int64 in
    let slots n =
      Time.Span.of_ms
        (to_float (n * of_int constants.constraints.block_window_duration_ms))
    in
    match t with
    | Epochs n ->
        Some
          (slots (of_int n * of_int constants.genesis.protocol.slots_per_epoch))
    | Slots n ->
        Some (slots (of_int n))
    | Literal span ->
        Some span
    | None ->
        None
end

type 'a predicate_result =
  | Predicate_passed
  | Predicate_continuation of 'a

(* NEED TO LIFT THIS UP OR FUNCTOR IT *)
type predicate =
  | Network_state_predicate : (Network_state.t -> 'a predicate_result) * ('a -> Network_state.t -> 'a predicate_result) -> predicate
  | Event_predicate : 'b Event_type.t * 'a * ('a -> Node.t -> 'b -> 'a predicate_result) -> predicate

type t =
  { predicate: predicate
  ; soft_timeout: Network_time_span.t
  ; hard_timeout: Network_time_span.t }

let node_to_initialize node =
  let open Network_state in
  let open Node in
  let check () (state : Network_state.t) =
    if String.Map.find_exn state.node_initialization node.pod_id then
      Predicate_passed
    else
      Predicate_continuation ()
  in
  let soft_timeout_in_mins = 2.0 in
  { predicate= Network_state_predicate (check (), check)
  ; soft_timeout= Literal (Time.Span.of_min soft_timeout_in_mins)
  ; hard_timeout= Literal (Time.Span.of_min (soft_timeout_in_mins *. 2.0)) }

(* let blocks_produced ?(active_stake_percentage = 1.0) n = *)
let blocks_to_be_produced n =
  let open Network_state in
  let init state = Predicate_continuation state.blocks_generated in
  let check init_blocks_generated state =
    if state.blocks_generated - init_blocks_generated >= n then
      Predicate_passed
    else
      Predicate_continuation init_blocks_generated
  in
  let soft_timeout_in_slots = 8 * n in
  { predicate= Network_state_predicate (init, check)
  ; soft_timeout= Slots soft_timeout_in_slots
  ; hard_timeout= Slots (soft_timeout_in_slots * 2) }

let payment_to_be_included_in_block ~sender ~receiver ~amount =
  let check () (block_produced : Event_type.Block_produced.t) =
  in
  { predicate= Event_predicate (Event_type.Block_produced, (), check)
  ; soft_timeout= ...
  ; hard_timeout= ... }
